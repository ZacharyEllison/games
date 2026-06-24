import { createServer } from "node:http";
/**
 * A tiny local HTTP control API on top of the relay, so anything that can make
 * an HTTP request (the CLI, curl, a shell-driven harness) can drive the game
 * without speaking MCP. Endpoints:
 *
 *   GET  /status            -> { connected, game }
 *   POST /call  {cmd,args,binary?}
 *        -> { ok, result }                              (normal)
 *        -> { ok, mimeType, base64, width, height }     (binary / screenshot)
 */
function pngSize(buf) {
    if (buf.length >= 24)
        return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
    return { width: 0, height: 0 };
}
function json(res, status, body) {
    const data = JSON.stringify(body);
    res.writeHead(status, { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(data) });
    res.end(data);
}
export function startControlServer(relay, port, host = "127.0.0.1") {
    return new Promise((resolve, reject) => {
        const srv = createServer((req, res) => {
            if (req.method === "GET" && req.url === "/status") {
                json(res, 200, { connected: relay.isConnected(), game: relay.gameInfo() });
                return;
            }
            if (req.method === "POST" && req.url === "/call") {
                let body = "";
                req.on("data", (chunk) => {
                    body += chunk;
                });
                req.on("end", async () => {
                    let payload;
                    try {
                        payload = JSON.parse(body || "{}");
                    }
                    catch {
                        json(res, 400, { ok: false, error: "invalid JSON body" });
                        return;
                    }
                    if (!payload.cmd) {
                        json(res, 400, { ok: false, error: "missing 'cmd'" });
                        return;
                    }
                    try {
                        const result = await relay.call(payload.cmd, payload.args ?? {}, { binary: payload.binary ?? false });
                        if (payload.binary && Buffer.isBuffer(result)) {
                            const { width, height } = pngSize(result);
                            json(res, 200, { ok: true, mimeType: "image/png", base64: result.toString("base64"), width, height });
                        }
                        else {
                            json(res, 200, { ok: true, result });
                        }
                    }
                    catch (err) {
                        json(res, 200, { ok: false, error: err.message });
                    }
                });
                return;
            }
            json(res, 404, { ok: false, error: "not found" });
        });
        srv.once("error", reject);
        srv.listen(port, host, () => resolve());
    });
}
