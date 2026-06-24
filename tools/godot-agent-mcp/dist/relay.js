import { WebSocketServer, WebSocket } from "ws";
import { EventEmitter } from "node:events";
function log(...args) {
    // Never write to stdout: it is reserved for the MCP stdio transport.
    console.error("[relay]", ...args);
}
export class GodotRelay extends EventEmitter {
    port;
    host;
    wss = null;
    game = null;
    pending = new Map();
    nextId = 1;
    info = null;
    constructor(port, host = "127.0.0.1") {
        super();
        this.port = port;
        this.host = host;
    }
    start() {
        return new Promise((resolve, reject) => {
            const wss = new WebSocketServer({ host: this.host, port: this.port });
            this.wss = wss;
            wss.once("error", reject);
            wss.on("listening", () => {
                log(`listening on ws://${this.host}:${this.port}`);
                resolve();
            });
            wss.on("connection", (ws) => this.onConnection(ws));
        });
    }
    isConnected() {
        return this.game !== null && this.game.readyState === WebSocket.OPEN;
    }
    gameInfo() {
        return this.info;
    }
    /** Resolve once a game is connected (or immediately if one already is). */
    waitForGame(timeoutMs = 30000) {
        if (this.isConnected() && this.info)
            return Promise.resolve(this.info);
        return new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
                this.off("hello", onHello);
                reject(new Error(`no game connected within ${timeoutMs}ms`));
            }, timeoutMs);
            const onHello = (info) => {
                clearTimeout(timer);
                resolve(info);
            };
            this.once("hello", onHello);
        });
    }
    /** Send a command to the game and await its reply. */
    call(cmd, args = {}, opts = {}) {
        const { binary = false, timeoutMs = 15000 } = opts;
        if (!this.isConnected() || !this.game) {
            return Promise.reject(new Error("no game connected"));
        }
        const id = this.nextId++;
        const game = this.game;
        return new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
                this.pending.delete(id);
                reject(new Error(`command "${cmd}" timed out after ${timeoutMs}ms`));
            }, timeoutMs);
            this.pending.set(id, { resolve, reject, timer, binary });
            game.send(JSON.stringify({ id, cmd, args }), (err) => {
                if (err) {
                    this.pending.delete(id);
                    clearTimeout(timer);
                    reject(err);
                }
            });
        });
    }
    onConnection(ws) {
        // Single-game model: a new connection supersedes the old one.
        if (this.game && this.game !== ws) {
            try {
                this.game.close();
            }
            catch {
                /* ignore */
            }
        }
        this.game = ws;
        log("game connected");
        ws.on("message", (data, isBinary) => this.onMessage(data, isBinary));
        ws.on("close", () => {
            if (this.game === ws) {
                this.game = null;
                this.info = null;
                log("game disconnected");
                this.emit("disconnect");
            }
            this.failAll("game disconnected");
        });
        ws.on("error", (err) => log("socket error:", err.message));
    }
    onMessage(data, isBinary) {
        if (isBinary) {
            this.onBinary(data);
            return;
        }
        let msg;
        try {
            msg = JSON.parse(data.toString());
        }
        catch {
            log("dropping non-JSON text frame");
            return;
        }
        if (msg.type === "hello") {
            this.info = {
                game: msg.game,
                platform: msg.platform,
                size: msg.size,
                scene: msg.scene,
            };
            log("hello:", JSON.stringify(this.info));
            this.emit("hello", this.info);
            return;
        }
        const id = typeof msg.id === "number" ? msg.id : -1;
        const pending = this.pending.get(id);
        if (!pending)
            return;
        this.pending.delete(id);
        clearTimeout(pending.timer);
        if (msg.ok === false) {
            pending.reject(new Error(String(msg.error ?? "game error")));
        }
        else {
            pending.resolve(msg.result ?? null);
        }
    }
    onBinary(buf) {
        if (buf.length < 4)
            return;
        const id = buf.readUInt32LE(0);
        const pending = this.pending.get(id);
        if (!pending)
            return;
        this.pending.delete(id);
        clearTimeout(pending.timer);
        pending.resolve(buf.subarray(4));
    }
    failAll(reason) {
        for (const [, p] of this.pending) {
            clearTimeout(p.timer);
            p.reject(new Error(reason));
        }
        this.pending.clear();
    }
}
