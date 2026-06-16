extends Node3D

# ── VR state ─────────────────────────────────────────────────────────────────
var webxr_interface: WebXRInterface
var _in_vr := false

# ── VR held brick ─────────────────────────────────────────────────────────────
var held_brick: Node3D = null
var _grabbed_type := ""
var _rotated_this_flick := false

# ── Desktop state ─────────────────────────────────────────────────────────────
var _desktop_type := "brick_1x1"
var _desktop_ghost: Brick = null
var _desktop_ghost_rot := 0.0   # cumulative Y rotation in degrees
var _placed_bricks: Array = []  # for undo

@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var cam: XRCamera3D            = $XROrigin3D/XRCamera3D
@onready var xr_origin: XROrigin3D     = $XROrigin3D
@onready var bricks_container: Node3D  = $Bricks
@onready var hud: HUD                  = $HUD
@onready var brick_palette: BrickPalette = $BrickPalette

func _ready() -> void:
	right_hand.button_pressed.connect(_on_right_button_pressed)
	right_hand.button_released.connect(_on_right_button_released)
	hud.reset_requested.connect(_on_reset)
	hud.enter_vr_requested.connect(_on_enter_vr)
	hud.brick_type_selected.connect(_on_desktop_type_changed)
	_init_webxr()

# ── WebXR lifecycle ──────────────────────────────────────────────────────────

func _init_webxr() -> void:
	webxr_interface = XRServer.find_interface("WebXR") as WebXRInterface
	if not webxr_interface:
		hud.set_vr_status("desktop")
		return
	webxr_interface.session_supported.connect(_webxr_session_supported)
	webxr_interface.session_started.connect(_webxr_session_started)
	webxr_interface.session_ended.connect(_webxr_session_ended)
	webxr_interface.session_failed.connect(_webxr_session_failed)
	webxr_interface.is_session_supported("immersive-vr")

func _webxr_session_supported(session_mode: String, supported: bool) -> void:
	if session_mode == "immersive-vr":
		hud.set_vr_status("supported" if supported else "unsupported")
		if not supported:
			hud.set_vr_status("desktop")

func _on_enter_vr() -> void:
	if not webxr_interface:
		return
	webxr_interface.session_mode = "immersive-vr"
	webxr_interface.requested_reference_space_types = "bounded-floor, local-floor, local"
	webxr_interface.required_features = "local-floor"
	webxr_interface.optional_features = "bounded-floor, hand-tracking"
	if not webxr_interface.initialize():
		OS.alert("Failed to start WebXR session")

func _webxr_session_started() -> void:
	_in_vr = true
	get_viewport().use_xr = true
	hud.on_xr_started()
	_kill_desktop_ghost()
	webxr_interface.squeezestart.connect(_on_squeeze_start)
	webxr_interface.squeezeend.connect(_on_squeeze_end)
	webxr_interface.visibility_state_changed.connect(_on_visibility_changed)
	_place_palette_in_front.call_deferred()

func _place_palette_in_front() -> void:
	var forward_xz := -cam.global_transform.basis.z
	forward_xz.y = 0.0
	if forward_xz.length_squared() < 0.001:
		forward_xz = Vector3(0, 0, -1)
	forward_xz = forward_xz.normalized()
	var eye := cam.global_position
	brick_palette.global_position = eye + forward_xz * 0.55 + Vector3(0, -0.35, 0)
	var look_target := eye
	look_target.y = brick_palette.global_position.y
	if look_target.distance_squared_to(brick_palette.global_position) > 0.001:
		brick_palette.look_at(look_target, Vector3.UP)

func _webxr_session_ended() -> void:
	_in_vr = false
	get_viewport().use_xr = false
	hud.on_xr_ended()

func _webxr_session_failed(message: String) -> void:
	OS.alert("WebXR failed: " + message)
	hud.set_vr_status("supported")

func _on_visibility_changed() -> void:
	get_tree().paused = (webxr_interface.visibility_state != "visible")

# ── VR grab input ─────────────────────────────────────────────────────────────

func _on_squeeze_start(input_source_id: int) -> void:
	if input_source_id == 1:
		_try_grab()

func _on_squeeze_end(input_source_id: int) -> void:
	if input_source_id == 1:
		_vr_release_brick()

func _on_right_button_pressed(button: String) -> void:
	if button == "grip_click":
		_try_grab()

func _on_right_button_released(button: String) -> void:
	if button == "grip_click":
		_vr_release_brick()

func _try_grab() -> void:
	if held_brick:
		return
	var type := brick_palette.get_nearest_type(right_hand.global_position)
	if type.is_empty():
		return
	_grabbed_type = type
	var scene: PackedScene = BrickPalette.BRICK_SCENES.get(type)
	if not scene:
		return
	held_brick = scene.instantiate()
	held_brick.scale = Vector3.ONE * GridSnapper.BRICK_SCALE
	bricks_container.add_child(held_brick)
	(held_brick as Brick).set_ghost(true)

func _vr_release_brick() -> void:
	if not held_brick:
		return
	var snap_pos := GridSnapper.snap(held_brick.global_position)
	snap_pos.y = GridSnapper.floor_y(_grabbed_type)
	held_brick.global_position = snap_pos
	var y_rot: float = round(held_brick.rotation.y / (PI * 0.5)) * (PI * 0.5)
	held_brick.rotation = Vector3(0, y_rot, 0)
	(held_brick as Brick).set_ghost(false)
	_placed_bricks.append(held_brick)
	AudioManager.play_place()
	held_brick = null

# ── Per-frame ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _in_vr:
		_process_vr()
	else:
		_process_desktop()

func _process_vr() -> void:
	if held_brick:
		held_brick.global_position = right_hand.global_position
		held_brick.global_rotation = right_hand.global_rotation
		var axes := right_hand.get_vector2("primary")
		if axes.x > 0.7 and not _rotated_this_flick:
			held_brick.rotate_y(deg_to_rad(90.0))
			_rotated_this_flick = true
		elif abs(axes.x) < 0.3:
			_rotated_this_flick = false
	else:
		brick_palette.update_highlight(right_hand.global_position)

func _process_desktop() -> void:
	_update_desktop_ghost()
	# Right-drag orbit
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var vel := Input.get_last_mouse_velocity() * 0.003
		xr_origin.rotation.y -= vel.x
		xr_origin.rotation.x = clamp(xr_origin.rotation.x - vel.y, -1.2, 0.1)

# ── Desktop interaction ───────────────────────────────────────────────────────

func _on_desktop_type_changed(type: String) -> void:
	_desktop_type = type
	_kill_desktop_ghost()   # will be recreated on next frame

func _desk_raycast() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var ray_origin := cam.project_ray_origin(mouse)
	var ray_dir   := cam.project_ray_normal(mouse)
	# Intersect with the horizontal desk plane at DESK_Y
	if ray_dir.y >= -0.001:
		return Vector3.INF
	var t := -(ray_origin.y - GridSnapper.DESK_Y) / ray_dir.y
	if t < 0.0 or t > 20.0:
		return Vector3.INF
	return ray_origin + ray_dir * t

func _update_desktop_ghost() -> void:
	var hit := _desk_raycast()
	if hit == Vector3.INF:
		if _desktop_ghost:
			_desktop_ghost.visible = false
		return

	# (Re)create ghost if missing or type changed
	if not _desktop_ghost:
		var scene := BrickPalette.BRICK_SCENES.get(_desktop_type) as PackedScene
		if not scene:
			return
		_desktop_ghost = scene.instantiate()
		_desktop_ghost.scale = Vector3.ONE * GridSnapper.BRICK_SCALE
		_desktop_ghost.rotation.y = deg_to_rad(_desktop_ghost_rot)
		bricks_container.add_child(_desktop_ghost)
		(_desktop_ghost as Brick).set_ghost(true)

	_desktop_ghost.visible = true
	var snap_pos := GridSnapper.snap(hit)
	snap_pos.y = GridSnapper.floor_y(_desktop_type)
	_desktop_ghost.global_position = snap_pos

func _kill_desktop_ghost() -> void:
	if _desktop_ghost:
		_desktop_ghost.queue_free()
		_desktop_ghost = null

func _input(event: InputEvent) -> void:
	if _in_vr:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_desktop_place()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_desktop_ghost_rot = fmod(_desktop_ghost_rot + 90.0, 360.0)
			if _desktop_ghost:
				_desktop_ghost.rotation.y = deg_to_rad(_desktop_ghost_rot)
		elif event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
			_desktop_undo()

func _desktop_place() -> void:
	var hit := _desk_raycast()
	if hit == Vector3.INF:
		return
	var scene := BrickPalette.BRICK_SCENES.get(_desktop_type) as PackedScene
	if not scene:
		return
	var brick: Brick = scene.instantiate()
	brick.scale = Vector3.ONE * GridSnapper.BRICK_SCALE
	bricks_container.add_child(brick)
	brick.set_ghost(true)   # initialise materials
	var snap_pos := GridSnapper.snap(hit)
	snap_pos.y = GridSnapper.floor_y(_desktop_type)
	brick.global_position = snap_pos
	brick.rotation.y = deg_to_rad(_desktop_ghost_rot)
	brick.set_ghost(false)
	_placed_bricks.append(brick)
	AudioManager.play_place()

func _desktop_undo() -> void:
	if _placed_bricks.is_empty():
		return
	var last: Node = _placed_bricks.pop_back()
	if is_instance_valid(last):
		last.queue_free()

# ── Reset ────────────────────────────────────────────────────────────────────

func _on_reset() -> void:
	_kill_desktop_ghost()
	if held_brick:
		held_brick.queue_free()
		held_brick = null
	_placed_bricks.clear()
	for child in bricks_container.get_children():
		child.queue_free()
	AudioManager.play_chime()
