extends Node3D

var held_brick: Node3D = null
var webxr_interface: WebXRInterface
var _rotated_this_flick := false
var _grabbed_type := ""

@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var bricks_container: Node3D = $Bricks
@onready var hud: HUD = $HUD
@onready var brick_palette: BrickPalette = $BrickPalette

func _ready() -> void:
	right_hand.button_pressed.connect(_on_right_button_pressed)
	right_hand.button_released.connect(_on_right_button_released)
	hud.reset_requested.connect(_on_reset)
	hud.enter_vr_requested.connect(_on_enter_vr)
	_init_webxr()

# ── WebXR lifecycle ──────────────────────────────────────────────────────────

func _init_webxr() -> void:
	webxr_interface = XRServer.find_interface("WebXR") as WebXRInterface
	if not webxr_interface:
		print("WebXR not available - desktop mode")
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
	print("WebXR started. Reference space: ", webxr_interface.reference_space_type)
	get_viewport().use_xr = true
	hud.on_xr_started()
	webxr_interface.squeezestart.connect(_on_squeeze_start)
	webxr_interface.squeezeend.connect(_on_squeeze_end)
	webxr_interface.visibility_state_changed.connect(_on_visibility_changed)

func _webxr_session_ended() -> void:
	get_viewport().use_xr = false
	hud.on_xr_ended()

func _webxr_session_failed(message: String) -> void:
	OS.alert("WebXR failed: " + message)
	hud.set_vr_status("supported")

func _on_visibility_changed() -> void:
	get_tree().paused = (webxr_interface.visibility_state != "visible")

# ── Grab input ───────────────────────────────────────────────────────────────

func _on_squeeze_start(input_source_id: int) -> void:
	if input_source_id == 1:
		_try_grab()

func _on_squeeze_end(input_source_id: int) -> void:
	if input_source_id == 1:
		_release_brick()

func _on_right_button_pressed(button: String) -> void:
	if button == "grip_click":
		_try_grab()

func _on_right_button_released(button: String) -> void:
	if button == "grip_click":
		_release_brick()

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

func _process(_delta: float) -> void:
	if held_brick:
		# Follow hand position and rotation freely while held
		held_brick.global_position = right_hand.global_position
		held_brick.global_rotation = right_hand.global_rotation

		# Y-rotate on thumbstick flick
		var axes := right_hand.get_vector2("primary")
		if axes.x > 0.7 and not _rotated_this_flick:
			held_brick.rotate_y(deg_to_rad(90.0))
			_rotated_this_flick = true
		elif abs(axes.x) < 0.3:
			_rotated_this_flick = false
	else:
		brick_palette.update_highlight(right_hand.global_position)

	# Desktop orbit camera
	if not webxr_interface or not webxr_interface.is_initialized():
		var cam_pivot := $XROrigin3D
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var vel := Input.get_last_mouse_velocity() * 0.002
			cam_pivot.rotation.y -= vel.x
			cam_pivot.rotation.x = clamp(cam_pivot.rotation.x - vel.y, -1.2, 0.1)

func _release_brick() -> void:
	if not held_brick:
		return
	# Snap to grid on release
	var dims: Vector3 = GridSnapper.BRICK_DEFS.get(_grabbed_type, Vector3.ONE)
	held_brick.global_position = GridSnapper.snap(held_brick.global_position, dims)
	# Keep only Y rotation (snap to 90-degree increments)
	var y_rot: float = round(held_brick.rotation.y / (PI / 2.0)) * (PI / 2.0)
	held_brick.rotation = Vector3(0, y_rot, 0)
	(held_brick as Brick).set_ghost(false)
	AudioManager.play_place()
	held_brick = null

# ── Desktop fallback ─────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if webxr_interface and webxr_interface.is_initialized():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not held_brick:
			_begin_hold_desktop()
		else:
			_release_brick()

func _begin_hold_desktop() -> void:
	var cam := $XROrigin3D/XRCamera3D as Camera3D
	var ray := cam.project_ray_normal(get_viewport().get_mouse_position())
	var origin := cam.global_position
	if ray.y >= 0.0:
		return
	var t := -origin.y / ray.y
	var hit := origin + ray * t
	_grabbed_type = "brick_1x1"
	held_brick = (BrickPalette.BRICK_SCENES["brick_1x1"] as PackedScene).instantiate()
	held_brick.scale = Vector3.ONE * GridSnapper.BRICK_SCALE
	bricks_container.add_child(held_brick)
	(held_brick as Brick).set_ghost(true)
	held_brick.global_position = hit

# ── Reset ────────────────────────────────────────────────────────────────────

func _on_reset() -> void:
	if held_brick:
		held_brick.queue_free()
		held_brick = null
	for child in bricks_container.get_children():
		child.queue_free()
	AudioManager.play_chime()
