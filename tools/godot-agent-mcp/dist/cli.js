#!/usr/bin/env node
import { spawn } from "node:child_process";
import { writeFileSync, readFileSync, openSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
/**
 * Shell-friendly client + daemon manager for the Godot agent relay.
 *
 * Lifecycle (the daemon stays running across commands because it is spawned
 * into its own session and detached from the launching shell):
 *   godot-agent-cli start | stop | restart | status
 *
 * Driving a connected game (talks to the running daemon over HTTP):
 *   godot-agent-cli screenshot [--out shot.png]
 *   godot-agent-cli input --kind key --keycode space
 *   godot-agent-cli input --kind touch --nx 0.5 --ny 0.5
 *   godot-agent-cli scene_tree [--max_depth 2]
 *   godot-agent-cli get_node --path /root/Main
 *   godot-agent-cli actions
 *   godot-agent-cli run_action --name place --args '{"x":1}'
 *   godot-agent-cli eval --code "Engine.get_frames_per_second()"
 *   godot-agent-cli wait --frames 5
 */
const CONTROL_PORT = Number(process.env.GODOT_CONTROL_PORT ?? 8788);
const BASE = `http://127.0.0.1:${CONTROL_PORT}`;
const PID_FILE = process.env.GODOT_AGENT_PIDFILE ?? join(tmpdir(), "godot-agent-mcp.pid");
const LOG_FILE = process.env.GODOT_AGENT_LOG ?? join(tmpdir(), "godot-agent-mcp.log");
const DAEMON_ENTRY = join(dirname(fileURLToPath(import.meta.url)), "index.js");
const TOOL_COMMANDS = new Set([
    "screenshot",
    "input",
    "scene_tree",
    "get_node",
    "actions",
    "run_action",
    "eval",
    "wait",
]);
const USAGE = `godot-agent-cli <command> [--flag value ...]

Daemon:   start | stop | restart | status
Tools:    screenshot, input, scene_tree, get_node, actions, run_action, eval, wait

Examples:
  godot-agent-cli start
  godot-agent-cli screenshot --out shot.png
  godot-agent-cli input --kind key --keycode space
  godot-agent-cli eval --code "Engine.get_frames_per_second()"

Env: GODOT_CONTROL_PORT (default 8788), GODOT_AGENT_PORT (relay, default 8787),
     GODOT_BIN, GODOT_AGENT_PIDFILE, GODOT_AGENT_LOG.`;
function coerce(v) {
    if (v === "true")
        return true;
    if (v === "false")
        return false;
    if (v !== "" && !Number.isNaN(Number(v)))
        return Number(v);
    if ((v.startsWith("{") && v.endsWith("}")) || (v.startsWith("[") && v.endsWith("]"))) {
        try {
            return JSON.parse(v);
        }
        catch {
            return v;
        }
    }
    return v;
}
function parseFlags(argv) {
    const args = {};
    for (let i = 0; i < argv.length; i++) {
        const token = argv[i];
        if (!token.startsWith("--"))
            continue;
        const key = token.slice(2);
        const next = argv[i + 1];
        if (next === undefined || next.startsWith("--")) {
            args[key] = true;
        }
        else {
            args[key] = coerce(next);
            i++;
        }
    }
    return args;
}
async function fetchStatus(timeoutMs = 1500) {
    try {
        const res = await fetch(`${BASE}/status`, { signal: AbortSignal.timeout(timeoutMs) });
        return await res.json();
    }
    catch {
        return null;
    }
}
function readPid() {
    if (!existsSync(PID_FILE))
        return null;
    const pid = Number(readFileSync(PID_FILE, "utf8").trim());
    return Number.isInteger(pid) && pid > 0 ? pid : null;
}
function pidAlive(pid) {
    try {
        process.kill(pid, 0);
        return true;
    }
    catch {
        return false;
    }
}
async function startDaemon() {
    const existing = await fetchStatus();
    if (existing) {
        console.log(JSON.stringify({ started: false, reason: "already running", ...existing }, null, 2));
        return;
    }
    const logFd = openSync(LOG_FILE, "a");
    const child = spawn(process.execPath, [DAEMON_ENTRY, "--serve"], {
        detached: true, // new session: survives the launching shell/command
        stdio: ["ignore", logFd, logFd],
        env: process.env,
    });
    child.unref();
    if (child.pid)
        writeFileSync(PID_FILE, String(child.pid));
    // Wait for the control API to come up.
    for (let i = 0; i < 40; i++) {
        await new Promise((r) => setTimeout(r, 100));
        if (await fetchStatus()) {
            console.log(JSON.stringify({ started: true, pid: child.pid, control: BASE, log: LOG_FILE }, null, 2));
            return;
        }
    }
    console.error(`daemon did not become ready; see ${LOG_FILE}`);
    process.exit(1);
}
function stopDaemon() {
    const pid = readPid();
    if (pid && pidAlive(pid)) {
        try {
            process.kill(pid);
        }
        catch {
            /* already gone */
        }
        console.log(JSON.stringify({ stopped: true, pid }, null, 2));
    }
    else {
        console.log(JSON.stringify({ stopped: false, reason: "not running" }, null, 2));
    }
    if (existsSync(PID_FILE))
        rmSync(PID_FILE);
}
async function main() {
    const [cmd, ...rest] = process.argv.slice(2);
    if (!cmd || cmd === "help" || cmd === "--help" || cmd === "-h") {
        console.log(USAGE);
        process.exit(cmd ? 0 : 1);
    }
    if (cmd === "start")
        return startDaemon();
    if (cmd === "stop")
        return stopDaemon();
    if (cmd === "restart") {
        stopDaemon();
        await new Promise((r) => setTimeout(r, 400));
        return startDaemon();
    }
    if (cmd === "status") {
        const status = await fetchStatus();
        if (!status) {
            console.log(JSON.stringify({ daemon: "not running", hint: "run: godot-agent-cli start" }, null, 2));
            process.exit(1);
        }
        console.log(JSON.stringify({ daemon: "running", control: BASE, ...status }, null, 2));
        return;
    }
    if (!TOOL_COMMANDS.has(cmd)) {
        console.error(`unknown command: ${cmd}\n\n${USAGE}`);
        process.exit(1);
    }
    const flags = parseFlags(rest);
    const binary = cmd === "screenshot";
    const out = typeof flags.out === "string" ? flags.out : undefined;
    delete flags.out;
    let res;
    try {
        res = await fetch(`${BASE}/call`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ cmd, args: flags, binary }),
        });
    }
    catch (e) {
        console.error(`cannot reach daemon at ${BASE} (${e.message}). Start it with: godot-agent-cli start`);
        process.exit(1);
    }
    const data = (await res.json());
    if (!data.ok) {
        console.error(`error: ${data.error ?? "unknown"}`);
        process.exit(1);
    }
    if (binary && data.base64) {
        const path = out ?? join(tmpdir(), `godot-shot-${Date.now()}.png`);
        writeFileSync(path, Buffer.from(data.base64, "base64"));
        console.log(JSON.stringify({ saved: path, width: data.width, height: data.height }, null, 2));
        return;
    }
    console.log(JSON.stringify(data.result ?? data, null, 2));
}
main().catch((err) => {
    console.error(err.message);
    process.exit(1);
});
