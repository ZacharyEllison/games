#!/usr/bin/env node
import { spawn } from "node:child_process";
import { resolve as resolvePath } from "node:path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { GodotRelay } from "./relay.js";
import { startControlServer } from "./control.js";
const RELAY_PORT = Number(process.env.GODOT_AGENT_PORT ?? 8787);
const CONTROL_PORT = Number(process.env.GODOT_CONTROL_PORT ?? 8788);
const GODOT_BIN = process.env.GODOT_BIN ?? "godot";
const SERVE_ONLY = process.argv.includes("--serve");
const relay = new GodotRelay(RELAY_PORT);
function log(...args) {
    console.error("[godot-agent-mcp]", ...args);
}
/** Standard text result. */
function textResult(value) {
    const text = typeof value === "string" ? value : JSON.stringify(value, null, 2);
    return { content: [{ type: "text", text }] };
}
function errorResult(message) {
    return { content: [{ type: "text", text: message }], isError: true };
}
/** Read width/height out of a PNG buffer (IHDR is at a fixed offset). */
function pngSize(buf) {
    if (buf.length >= 24) {
        return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
    }
    return { width: 0, height: 0 };
}
async function callGame(cmd, args = {}, binary = false) {
    return relay.call(cmd, args, { binary });
}
const server = new McpServer({
    name: "godot-agent-mcp",
    version: "0.1.0",
});
// ---------------------------------------------------------------------------
// launch_game - start a desktop/headless game that dials back into the relay.
// (For web exports you just open the page; the game connects on its own.)
// ---------------------------------------------------------------------------
server.registerTool("launch_game", {
    title: "Launch a Godot game",
    description: "Launch a Godot project (desktop or headless) with the --agent flag so it connects back to this relay. " +
        "Returns the game's hello info once connected. For web exports, skip this and just open the page.",
    inputSchema: {
        project_path: z.string().describe("Absolute or relative path to the Godot project directory (containing project.godot)."),
        headless: z.boolean().optional().describe("Run without a window (default false). Note: headless cannot capture screenshots."),
        godot_bin: z.string().optional().describe("Path to the Godot executable. Defaults to $GODOT_BIN or 'godot'."),
        wait_ms: z.number().optional().describe("How long to wait for the game to connect (default 30000)."),
    },
}, async ({ project_path, headless, godot_bin, wait_ms }) => {
    const bin = godot_bin ?? GODOT_BIN;
    const projectDir = resolvePath(project_path);
    const cliArgs = ["--path", projectDir];
    if (headless)
        cliArgs.push("--headless");
    cliArgs.push("--", "--agent", `--agent-url=ws://127.0.0.1:${RELAY_PORT}`);
    log(`launching: ${bin} ${cliArgs.join(" ")}`);
    let child;
    try {
        child = spawn(bin, cliArgs, { stdio: "ignore", detached: false });
    }
    catch (err) {
        return errorResult(`failed to spawn Godot (${bin}): ${err.message}`);
    }
    child.on("error", (err) => log("godot process error:", err.message));
    try {
        const info = await relay.waitForGame(wait_ms ?? 30000);
        return textResult({ launched: true, ...info });
    }
    catch (err) {
        return errorResult(`launched but no connection: ${err.message}. ` +
            `Check that $GODOT_BIN is correct and the AgentLink autoload is installed in the project.`);
    }
});
// ---------------------------------------------------------------------------
// screenshot
// ---------------------------------------------------------------------------
server.registerTool("screenshot", {
    title: "Screenshot the game",
    description: "Capture the current game viewport as a PNG image. Works for 2D and 3D. Returns the image inline.",
    inputSchema: {},
}, async () => {
    try {
        const buf = (await callGame("screenshot", {}, true));
        const { width, height } = pngSize(buf);
        return {
            content: [
                { type: "image", data: buf.toString("base64"), mimeType: "image/png" },
                { type: "text", text: `${width}x${height}` },
            ],
        };
    }
    catch (err) {
        return errorResult(`screenshot failed: ${err.message}`);
    }
});
// ---------------------------------------------------------------------------
// input - one tool for every kind of synthetic input.
// ---------------------------------------------------------------------------
server.registerTool("input", {
    title: "Simulate input",
    description: "Inject a synthetic input event into the running game. " +
        "kinds: 'key' (keycode like 'space'/'enter'/'a'), 'mouse_button' (button left/right/middle + x,y), " +
        "'mouse_move' (x,y), 'touch' (index,x,y,pressed - for mobile), 'drag' (index,x,y,dx,dy), " +
        "'action' (InputMap action name), 'text' (types a string). " +
        "Positions accept x,y in pixels OR nx,ny normalized 0..1 for resolution independence.",
    inputSchema: {
        kind: z.enum(["key", "mouse_button", "mouse_move", "touch", "drag", "action", "text"]),
        keycode: z.string().optional().describe("For 'key': key name e.g. 'space','enter','a','up'."),
        pressed: z.boolean().optional().describe("Press (true) vs release (false). If omitted, a full press+release is sent."),
        button: z.string().optional().describe("For 'mouse_button': 'left','right','middle','1'..'5'."),
        action: z.string().optional().describe("For 'action': the InputMap action name."),
        text: z.string().optional().describe("For 'text': the string to type."),
        index: z.number().optional().describe("For 'touch'/'drag': finger index (default 0)."),
        x: z.number().optional(),
        y: z.number().optional(),
        nx: z.number().optional().describe("Normalized x (0..1)."),
        ny: z.number().optional().describe("Normalized y (0..1)."),
        dx: z.number().optional().describe("Relative delta x (mouse_move/drag)."),
        dy: z.number().optional().describe("Relative delta y (mouse_move/drag)."),
        ctrl: z.boolean().optional(),
        alt: z.boolean().optional(),
        shift: z.boolean().optional(),
    },
}, async (args) => {
    try {
        return textResult(await callGame("input", args));
    }
    catch (err) {
        return errorResult(`input failed: ${err.message}`);
    }
});
// ---------------------------------------------------------------------------
// scene_tree / get_node - introspection
// ---------------------------------------------------------------------------
server.registerTool("scene_tree", {
    title: "Get the scene tree",
    description: "Return the running scene's node hierarchy (names, types, paths, key transform props).",
    inputSchema: {
        max_depth: z.number().optional().describe("Max depth to traverse; -1 (default) for unlimited."),
    },
}, async ({ max_depth }) => {
    try {
        return textResult(await callGame("scene_tree", { max_depth: max_depth ?? -1 }));
    }
    catch (err) {
        return errorResult(`scene_tree failed: ${err.message}`);
    }
});
server.registerTool("get_node", {
    title: "Get a node's properties",
    description: "Return the properties of a single node, e.g. path '/root/Main/Player'.",
    inputSchema: {
        path: z.string().describe("Node path, e.g. '/root/Main/Player'."),
    },
}, async ({ path }) => {
    try {
        return textResult(await callGame("get_node", { path }));
    }
    catch (err) {
        return errorResult(`get_node failed: ${err.message}`);
    }
});
// ---------------------------------------------------------------------------
// actions / run_action - game-defined high-level hooks
// ---------------------------------------------------------------------------
server.registerTool("actions", {
    title: "List game actions",
    description: "List high-level actions the running game exposes (a node in the 'agent_actions' group with an agent_actions() method). " +
        "Empty if the game defines none.",
    inputSchema: {},
}, async () => {
    try {
        return textResult(await callGame("actions"));
    }
    catch (err) {
        return errorResult(`actions failed: ${err.message}`);
    }
});
server.registerTool("run_action", {
    title: "Run a game action",
    description: "Invoke a game-defined high-level action by name with optional arguments.",
    inputSchema: {
        name: z.string().describe("Action name (see the 'actions' tool)."),
        args: z.record(z.unknown()).optional().describe("Arguments object passed to the action."),
    },
}, async ({ name, args }) => {
    try {
        return textResult(await callGame("run_action", { name, args: args ?? {} }));
    }
    catch (err) {
        return errorResult(`run_action failed: ${err.message}`);
    }
});
// ---------------------------------------------------------------------------
// eval - guarded GDScript expression evaluation
// ---------------------------------------------------------------------------
server.registerTool("eval", {
    title: "Evaluate a GDScript expression",
    description: "Evaluate a GDScript expression in the running game using Godot's Expression class (for debugging). " +
        "Common singletons (OS, Engine, Input, Time, Performance, ...) are bound.",
    inputSchema: {
        code: z.string().describe("A GDScript expression, e.g. 'Engine.get_frames_per_second()'."),
    },
}, async ({ code }) => {
    try {
        return textResult(await callGame("eval", { code }));
    }
    catch (err) {
        return errorResult(`eval failed: ${err.message}`);
    }
});
// ---------------------------------------------------------------------------
// wait - let the game advance before the next observation
// ---------------------------------------------------------------------------
server.registerTool("wait", {
    title: "Wait / settle",
    description: "Let the game run for a number of frames or milliseconds before the next screenshot. Provide one of frames or ms.",
    inputSchema: {
        frames: z.number().optional().describe("Number of process frames to advance."),
        ms: z.number().optional().describe("Milliseconds of real time to wait."),
    },
}, async ({ frames, ms }) => {
    try {
        return textResult(await callGame("wait", { frames, ms }, false));
    }
    catch (err) {
        return errorResult(`wait failed: ${err.message}`);
    }
});
async function main() {
    try {
        await relay.start();
    }
    catch (err) {
        if (err.code === "EADDRINUSE") {
            log(`relay port ${RELAY_PORT} is already in use - another instance or '--serve' daemon is ` +
                `already running. Use that one (don't start a second), or set GODOT_AGENT_PORT.`);
        }
        else {
            log("relay failed to start:", err);
        }
        process.exit(1);
    }
    // The HTTP control API powers the CLI / shell-driven use. Best-effort in MCP
    // mode (a busy port just means no CLI), required in --serve mode.
    try {
        await startControlServer(relay, CONTROL_PORT);
        log(`control API on http://127.0.0.1:${CONTROL_PORT}`);
    }
    catch (err) {
        if (SERVE_ONLY) {
            log(`control port ${CONTROL_PORT} is in use; set GODOT_CONTROL_PORT.`);
            process.exit(1);
        }
        log(`control API disabled (port ${CONTROL_PORT} in use).`);
    }
    if (SERVE_ONLY) {
        // Daemon mode: relay + control only, no MCP stdio. Drive it with the CLI.
        log(`daemon ready. relay ws://127.0.0.1:${RELAY_PORT}, godot bin '${GODOT_BIN}'. Use 'godot-agent-cli ...'.`);
        return;
    }
    const transport = new StdioServerTransport();
    await server.connect(transport);
    log(`ready (MCP stdio). relay ws://127.0.0.1:${RELAY_PORT}, godot bin '${GODOT_BIN}'.`);
}
main().catch((err) => {
    log("fatal:", err);
    process.exit(1);
});
