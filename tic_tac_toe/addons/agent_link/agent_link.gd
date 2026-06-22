extends Node
## AgentLink - a thin agent control surface for any Godot game.
##
## Activates ONLY when the game is launched with the `--agent` user flag, so it
## is a no-op in normal play / production builds. When active it dials OUT to a
## local WebSocket relay (default ws://127.0.0.1:8787) and answers a small set
## of commands: screenshot, input, scene_tree, get_node, actions, run_action,
## eval, wait.
##
## Dialing out (rather than hosting a socket) is what makes this work on every
## target: Godot web exports cannot open listening sockets, but WebSocketPeer
## can connect out from web, desktop, and mobile alike.
##
## This file is the canonical source. It is synced into each project's
## addons/agent_link/ by tools/godot-agent-mcp/scripts/sync-godot.mjs.

const DEFAULT_URL := "ws://127.0.0.1:8787"
const RECONNECT_INTERVAL := 2.0

var _socket: WebSocketPeer
var _connected := false
var _active := false
var _url := DEFAULT_URL
var _reconnect_accum := 0.0


func _ready() -> void:
    var user_args := OS.get_cmdline_user_args()
    if not ("--agent" in user_args):
        set_process(false)
        return
    _active = true
    for arg in user_args:
        if arg.begins_with("--agent-url="):
            _url = arg.substr("--agent-url=".length())
    _socket = WebSocketPeer.new()
    _open()


func _open() -> void:
    # Screenshots are sent as a single binary frame; default 64 KB buffers are
    # too small for 3D/high-res captures, so size them up generously.
    _socket.inbound_buffer_size = 1 << 24 # 16 MB
    _socket.outbound_buffer_size = 1 << 24 # 16 MB
    _socket.max_queued_packets = 64
    var err := _socket.connect_to_url(_url)
    if err != OK:
        push_warning("[AgentLink] connect_to_url(%s) failed: %s" % [_url, err])


func _process(delta: float) -> void:
    if not _active:
        return
    _socket.poll()
    match _socket.get_ready_state():
        WebSocketPeer.STATE_OPEN:
            if not _connected:
                _connected = true
                _send_hello()
            while _socket.get_available_packet_count() > 0:
                _handle_packet(_socket.get_packet(), _socket.was_string_packet())
        WebSocketPeer.STATE_CLOSED:
            _connected = false
            _reconnect_accum += delta
            if _reconnect_accum >= RECONNECT_INTERVAL:
                _reconnect_accum = 0.0
                _socket = WebSocketPeer.new()
                _open()

# ---------------------------------------------------------------------------
# Transport
# ---------------------------------------------------------------------------


func _send_hello() -> void:
    var root := _scene_root()
    var size := _viewport_size()
    _socket.send_text(
        JSON.stringify(
            {
                "type": "hello",
                "game": str(ProjectSettings.get_setting("application/config/name", "")),
                "platform": OS.get_name(),
                "size": [int(size.x), int(size.y)],
                "scene": root.name if root else "",
            },
        ),
    )


func _handle_packet(packet: PackedByteArray, is_text: bool) -> void:
    if not is_text:
        return # The relay only ever sends text commands.
    var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var id := int(parsed.get("id", -1))
    var cmd := str(parsed.get("cmd", ""))
    var args: Dictionary = parsed.get("args", { })
    _dispatch(id, cmd, args)


func _reply_ok(id: int, result: Variant) -> void:
    _socket.send_text(JSON.stringify({ "id": id, "ok": true, "result": result }))


func _reply_err(id: int, message: String) -> void:
    _socket.send_text(JSON.stringify({ "id": id, "ok": false, "error": message }))


func _reply_binary(id: int, payload: PackedByteArray) -> void:
    var frame := PackedByteArray()
    frame.resize(4)
    frame.encode_u32(0, id) # little-endian, matches relay readUInt32LE
    frame.append_array(payload)
    _socket.send(frame) # binary write mode

# ---------------------------------------------------------------------------
# Command dispatch
# ---------------------------------------------------------------------------


func _dispatch(id: int, cmd: String, args: Dictionary) -> void:
    match cmd:
        "screenshot":
            _do_screenshot(id)
        "input":
            _reply_ok(id, _do_input(args))
        "scene_tree":
            _reply_ok(id, _do_scene_tree(args))
        "get_node":
            _reply_ok(id, _do_get_node(args))
        "actions":
            _reply_ok(id, _do_actions())
        "run_action":
            _reply_ok(id, _do_run_action(args))
        "eval":
            _reply_ok(id, _do_eval(args))
        "wait":
            await _do_wait(id, args)
        _:
            _reply_err(id, "unknown command: " + cmd)


func _do_screenshot(id: int) -> void:
    var viewport := get_viewport()
    if viewport == null:
        _reply_err(id, "no viewport")
        return
    var tex := viewport.get_texture()
    if tex == null:
        _reply_err(id, "no viewport texture")
        return
    var image := tex.get_image()
    if image == null or image.is_empty():
        _reply_err(id, "empty image")
        return
    _reply_binary(id, image.save_png_to_buffer())


func _do_wait(id: int, args: Dictionary) -> void:
    if args.has("ms") and args.get("ms") != null:
        await get_tree().create_timer(float(args.get("ms")) / 1000.0).timeout
    else:
        var frames := int(args.get("frames", 1))
        for _i in range(max(1, frames)):
            await get_tree().process_frame
    _reply_ok(id, { "status": "ok" })

# ---------------------------------------------------------------------------
# Input simulation
# ---------------------------------------------------------------------------


func _do_input(args: Dictionary) -> Dictionary:
    var kind := str(args.get("kind", ""))
    match kind:
        "key":
            return _input_key(args)
        "text":
            return _input_text(args)
        "mouse_button":
            return _input_mouse_button(args)
        "mouse_move":
            return _input_mouse_move(args)
        "touch":
            return _input_touch(args)
        "drag":
            return _input_drag(args)
        "action":
            return _input_action(args)
    return { "error": "unknown input kind: " + kind }


func _input_key(args: Dictionary) -> Dictionary:
    var keycode := _keycode_from_string(str(args.get("keycode", "")))
    if keycode == 0:
        return { "error": "unknown keycode: " + str(args.get("keycode", "")) }
    if args.has("pressed"):
        _push_key(keycode, bool(args.get("pressed")), args)
    else:
        _push_key(keycode, true, args)
        _push_key(keycode, false, args)
    return { "status": "ok", "kind": "key" }


func _push_key(keycode: int, pressed: bool, args: Dictionary) -> void:
    var ev := InputEventKey.new()
    ev.keycode = keycode
    ev.physical_keycode = keycode
    ev.pressed = pressed
    ev.ctrl_pressed = bool(args.get("ctrl", false))
    ev.alt_pressed = bool(args.get("alt", false))
    ev.shift_pressed = bool(args.get("shift", false))
    Input.parse_input_event(ev)


func _input_text(args: Dictionary) -> Dictionary:
    var text := str(args.get("text", ""))
    for i in range(text.length()):
        var down := InputEventKey.new()
        down.unicode = text.unicode_at(i)
        down.pressed = true
        Input.parse_input_event(down)
        var up := InputEventKey.new()
        up.unicode = text.unicode_at(i)
        up.pressed = false
        Input.parse_input_event(up)
    return { "status": "ok", "kind": "text", "length": text.length() }


func _input_mouse_button(args: Dictionary) -> Dictionary:
    var pos := _resolve_pos(args)
    if args.has("pressed"):
        _push_mouse_button(pos, _button_index_from_string(str(args.get("button", "left"))), bool(args.get("pressed")))
    else:
        _push_mouse_button(pos, _button_index_from_string(str(args.get("button", "left"))), true)
        _push_mouse_button(pos, _button_index_from_string(str(args.get("button", "left"))), false)
    return { "status": "ok", "kind": "mouse_button", "x": pos.x, "y": pos.y }


func _push_mouse_button(pos: Vector2, button_index: int, pressed: bool) -> void:
    var ev := InputEventMouseButton.new()
    ev.button_index = button_index
    ev.pressed = pressed
    ev.position = pos
    ev.global_position = pos
    Input.parse_input_event(ev)


func _input_mouse_move(args: Dictionary) -> Dictionary:
    var pos := _resolve_pos(args)
    var ev := InputEventMouseMotion.new()
    ev.position = pos
    ev.global_position = pos
    ev.relative = Vector2(float(args.get("dx", 0)), float(args.get("dy", 0)))
    Input.parse_input_event(ev)
    return { "status": "ok", "kind": "mouse_move", "x": pos.x, "y": pos.y }


func _input_touch(args: Dictionary) -> Dictionary:
    var pos := _resolve_pos(args)
    var ev := InputEventScreenTouch.new()
    ev.index = int(args.get("index", 0))
    ev.position = pos
    ev.pressed = bool(args.get("pressed", true))
    Input.parse_input_event(ev)
    return { "status": "ok", "kind": "touch", "x": pos.x, "y": pos.y }


func _input_drag(args: Dictionary) -> Dictionary:
    var pos := _resolve_pos(args)
    var ev := InputEventScreenDrag.new()
    ev.index = int(args.get("index", 0))
    ev.position = pos
    ev.relative = Vector2(float(args.get("dx", 0)), float(args.get("dy", 0)))
    Input.parse_input_event(ev)
    return { "status": "ok", "kind": "drag", "x": pos.x, "y": pos.y }


func _input_action(args: Dictionary) -> Dictionary:
    var action_name := str(args.get("action", ""))
    if not InputMap.has_action(action_name):
        return { "error": "unknown action: " + action_name }
    if args.has("pressed"):
        if bool(args.get("pressed")):
            Input.action_press(action_name)
        else:
            Input.action_release(action_name)
    else:
        Input.action_press(action_name)
        Input.action_release(action_name)
    return { "status": "ok", "kind": "action", "action": action_name }


func _resolve_pos(args: Dictionary) -> Vector2:
    if args.has("nx") or args.has("ny"):
        var size := _viewport_size()
        return Vector2(float(args.get("nx", 0)) * size.x, float(args.get("ny", 0)) * size.y)
    return Vector2(float(args.get("x", 0)), float(args.get("y", 0)))

# ---------------------------------------------------------------------------
# Game-defined actions (kept in the game, not the tool)
# ---------------------------------------------------------------------------


func _actions_provider() -> Node:
    var nodes := get_tree().get_nodes_in_group("agent_actions")
    return nodes[0] if nodes.size() > 0 else null


func _do_actions() -> Dictionary:
    var provider := _actions_provider()
    if provider and provider.has_method("agent_actions"):
        return { "actions": provider.agent_actions() }
    return { "actions": { } }


func _do_run_action(args: Dictionary) -> Dictionary:
    var provider := _actions_provider()
    if provider == null or not provider.has_method("agent_run_action"):
        return { "error": "no agent_actions provider in scene" }
    var name := str(args.get("name", ""))
    var action_args: Dictionary = args.get("args", { })
    var result: Variant = provider.agent_run_action(name, action_args)
    return { "status": "ok", "result": _serialize_value(result) }

# ---------------------------------------------------------------------------
# Eval (guarded expression evaluation, for debugging)
# ---------------------------------------------------------------------------


func _do_eval(args: Dictionary) -> Dictionary:
    var code := str(args.get("code", ""))
    if code.is_empty():
        return { "error": "missing code" }
    var expression := Expression.new()
    var names := PackedStringArray(
        [
            "OS",
            "Engine",
            "ProjectSettings",
            "Input",
            "Time",
            "JSON",
            "ClassDB",
            "Performance",
            "ResourceLoader",
        ],
    )
    var values: Array = [
        OS,
        Engine,
        ProjectSettings,
        Input,
        Time,
        JSON,
        ClassDB,
        Performance,
        ResourceLoader,
    ]
    if expression.parse(code, names) != OK:
        return { "error": "parse: " + expression.get_error_text() }
    var result: Variant = expression.execute(values, self, true)
    if expression.has_execute_failed():
        return { "error": "execute: " + expression.get_error_text() }
    return { "status": "ok", "result": str(result) }

# ---------------------------------------------------------------------------
# Scene introspection
# ---------------------------------------------------------------------------


func _scene_root() -> Node:
    # The actual running main scene (excludes autoloads like AgentLink).
    var current := get_tree().current_scene
    if current:
        return current
    # Fallback: last non-autoload, non-self child of root.
    var root := get_tree().root
    for i in range(root.get_child_count() - 1, -1, -1):
        var child := root.get_child(i)
        if child != self and not child.name.begins_with("@"):
            return child
    return null


func _viewport_size() -> Vector2:
    var vp := get_viewport()
    return vp.get_visible_rect().size if vp else Vector2.ZERO


func _do_scene_tree(args: Dictionary) -> Dictionary:
    var max_depth := int(args.get("max_depth", -1))
    var root := _scene_root()
    if root == null:
        return { "error": "no scene root" }
    return {
        "scene_name": root.name,
        "tree": _build_tree(root, 0, max_depth, root),
        "total_nodes": _count_nodes(root),
    }


func _do_get_node(args: Dictionary) -> Dictionary:
    var path := str(args.get("path", ""))
    if path.is_empty():
        return { "error": "missing path" }
    var root := _scene_root()
    if root == null:
        return { "error": "no scene root" }
    var node := _resolve_path(path, root)
    if node == null:
        return { "error": "node not found: " + path }
    var properties := { }
    for entry in node.get_property_list():
        var prop_name := str(entry.get("name", ""))
        if prop_name.begins_with("__"):
            continue
        var usage := int(entry.get("usage", 0))
        if usage & 128 or usage & 64 or usage & 256:
            continue
        properties[prop_name] = _serialize_value(node.get(prop_name))
    return { "node_path": path, "node_type": node.get_class(), "properties": properties }


func _resolve_path(path: String, root: Node) -> Node:
    if path == "/root" or path.is_empty():
        return root
    var relative := path.trim_prefix("/root/")
    var parts := relative.split("/")
    if parts.size() > 0 and parts[0] == root.name:
        if parts.size() == 1:
            return root
        return root.get_node_or_null("/".join(parts.slice(1)))
    return root.get_node_or_null(relative)


func _friendly_path(node: Node, root: Node) -> String:
    if node == root:
        return "/root/" + root.name
    var node_path := str(node.get_path())
    var root_path := str(root.get_path())
    if node_path.begins_with(root_path + "/"):
        return "/root/" + root.name + node_path.substr(root_path.length())
    return node_path


func _build_tree(node: Node, depth: int, max_depth: int, root: Node) -> Dictionary:
    var info := {
        "name": node.name,
        "type": node.get_class(),
        "path": _friendly_path(node, root),
        "child_count": node.get_child_count(),
    }
    var props := { }
    for prop_name in ["visible", "position", "rotation", "scale", "modulate"]:
        if prop_name in node:
            props[prop_name] = _serialize_value(node.get(prop_name))
    if props.size() > 0:
        info["properties"] = props
    if max_depth >= 0 and depth >= max_depth:
        if node.get_child_count() > 0:
            info["children_truncated"] = true
        return info
    if node.get_child_count() > 0:
        var children := []
        for child in node.get_children():
            children.append(_build_tree(child, depth + 1, max_depth, root))
        info["children"] = children
    return info


func _count_nodes(node: Node) -> int:
    var count := 1
    for child in node.get_children():
        count += _count_nodes(child)
    return count


func _serialize_value(value: Variant) -> Variant:
    if value == null:
        return null
    match typeof(value):
        TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
            return value
        TYPE_VECTOR2, TYPE_VECTOR2I:
            return { "x": value.x, "y": value.y }
        TYPE_VECTOR3, TYPE_VECTOR3I:
            return { "x": value.x, "y": value.y, "z": value.z }
        TYPE_VECTOR4, TYPE_VECTOR4I:
            return { "x": value.x, "y": value.y, "z": value.z, "w": value.w }
        TYPE_COLOR:
            return { "r": value.r, "g": value.g, "b": value.b, "a": value.a }
        TYPE_ARRAY:
            var arr := []
            for item in value:
                arr.append(_serialize_value(item))
            return arr
        TYPE_DICTIONARY:
            var dict := { }
            for key in value:
                dict[str(key)] = _serialize_value(value[key])
            return dict
        _:
            return str(value)

# ---------------------------------------------------------------------------
# Key / button maps
# ---------------------------------------------------------------------------


func _keycode_from_string(key_str: String) -> int:
    var keymap := {
        "space": KEY_SPACE,
        "enter": KEY_ENTER,
        "return": KEY_ENTER,
        "tab": KEY_TAB,
        "backspace": KEY_BACKSPACE,
        "escape": KEY_ESCAPE,
        "esc": KEY_ESCAPE,
        "delete": KEY_DELETE,
        "up": KEY_UP,
        "down": KEY_DOWN,
        "left": KEY_LEFT,
        "right": KEY_RIGHT,
        "shift": KEY_SHIFT,
        "ctrl": KEY_CTRL,
        "alt": KEY_ALT,
        "a": KEY_A,
        "b": KEY_B,
        "c": KEY_C,
        "d": KEY_D,
        "e": KEY_E,
        "f": KEY_F,
        "g": KEY_G,
        "h": KEY_H,
        "i": KEY_I,
        "j": KEY_J,
        "k": KEY_K,
        "l": KEY_L,
        "m": KEY_M,
        "n": KEY_N,
        "o": KEY_O,
        "p": KEY_P,
        "q": KEY_Q,
        "r": KEY_R,
        "s": KEY_S,
        "t": KEY_T,
        "u": KEY_U,
        "v": KEY_V,
        "w": KEY_W,
        "x": KEY_X,
        "y": KEY_Y,
        "z": KEY_Z,
        "0": KEY_0,
        "1": KEY_1,
        "2": KEY_2,
        "3": KEY_3,
        "4": KEY_4,
        "5": KEY_5,
        "6": KEY_6,
        "7": KEY_7,
        "8": KEY_8,
        "9": KEY_9,
    }
    return keymap.get(key_str.to_lower(), 0)


func _button_index_from_string(btn_str: String) -> int:
    var btnmap := {
        "left": MOUSE_BUTTON_LEFT,
        "1": MOUSE_BUTTON_LEFT,
        "middle": MOUSE_BUTTON_MIDDLE,
        "2": MOUSE_BUTTON_MIDDLE,
        "right": MOUSE_BUTTON_RIGHT,
        "3": MOUSE_BUTTON_RIGHT,
        "4": MOUSE_BUTTON_XBUTTON1,
        "5": MOUSE_BUTTON_XBUTTON2,
    }
    return btnmap.get(btn_str.to_lower(), MOUSE_BUTTON_LEFT)
