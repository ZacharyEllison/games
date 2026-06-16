extends Node3D

const BRICK_SCENES := {
	"brick_1x1":       preload("res://scenes/brick_1x1.tscn"),
	"brick_1x2":       preload("res://scenes/brick_1x2.tscn"),
	"brick_2x2":       preload("res://scenes/brick_2x2.tscn"),
	"brick_1x4":       preload("res://scenes/brick_1x4.tscn"),
	"brick_2x4":       preload("res://scenes/brick_2x4.tscn"),
	"plate_1x1":       preload("res://scenes/plate_1x1.tscn"),
	"plate_1x2":       preload("res://scenes/plate_1x2.tscn"),
	"plate_2x2":       preload("res://scenes/plate_2x2.tscn"),
	"brick_corner":    preload("res://scenes/brick_corner.tscn"),
	"brick_slope_1x2": preload("res://scenes/brick_slope_1x2.tscn"),
}

var selected_type: String = "brick_1x1"
var held_brick: Node3D = null
var webxr_interface: WebXRInterface
var _rotated_this_flick := false

@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var bricks_container: Node3D = $Bricks
@onready var hud: HUD = $HUD

func _ready() -> void:
	right_hand.button_pressed.connect(_on_right_button_pressed)
	right_hand.button_released.connect(_on_right_button_released)
	hud.brick_selected.connect(_on_brick_selected)
	hud.reset_requested.connect(_on_reset)
	hud.enter_vr_requested.connect(_on_enter_vr)
	_init_webxr()

# ── WebXR lifecycle ──────────────────────────────────────────────────────────

func _init_webxr() -> void:
	webxr_interface = XRServer.find_interface("WebXR") as WebXRInterface
	if not webxr_interface:
		# Running in editor or non-web build — desktop fallback mode.
		print("WebXR not available — desktop mode")
		hud.set_vr_status("desktop")
		return

	webxr_interface.session_supported.connect(_webxr_session_supported)
	webxr_interface.session_started.connect(_webxr_session_started)
	webxr_interface.session_ended.connect(_webxr_session_ended)
	webxr_interface.session_failed.connect(_webxr_session_failed)

	# Async — result comes back via session_supported signal.
	webxr_interface.is_session_supported("immersive-vr")

func _webxr_session_supported(session_mode: String, supported: bool) -> void:
	if session_mode == "immersive-vr":
		hud.set_vr_status("supported" if supported else "unsupported")

func _on_enter_vr() -> void:
	if not webxr_interface:
		return
	webxr_interface.session_mode = "immersive-vr"
	# Preference order: room scale → standing floor → seated/local.
	webxr_interface.requested_reference_space_types = "bounded-floor, local-floor, local"
	# required_features must include any space type you want to actually use.
	webxr_interface.required_features = "local-floor"
	# bounded-floor (room scale) and hand-tracking are nice but not mandatory.
	webxr_interface.optional_features = "bounded-floor, hand-tracking"
	if not webxr_interface.initialize():
		OS.alert("Failed to start WebXR session")

func _webxr_session_started() -> void:
	print("WebXR started. Reference space: ", webxr_interface.reference_space_type)
	print("Enabled features: ", webxr_interface.enabled_features)
	get_viewport().use_xr = true
	hud.on_xr_started()
	# Squeeze signals work on all WebXR devices, including simpler ones that
	# don't report named buttons via XRController3D.
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
	# visibility_state: "visible" | "visible-blurred" (system menu) | "hidden" (headset off)
	get_tree().paused = (webxr_interface.visibility_state != "visible")

# ── Grip / squeeze input ─────────────────────────────────────────────────────
# Primary path: WebXRInterface signals (all WebXR devices).
# Fallback path: XRController3D.button_pressed (advanced controllers).

func _on_squeeze_start(input_source_id: int) -> void:
	# 0 = left, 1 = right hand (verify with print at runtime if needed)
	if input_source_id == 1:
		_begin_hold()

func _on_squeeze_end(input_source_id: int) -> void:
	if input_source_id == 1:
		_place_brick()

func _on_right_button_pressed(button: String) -> void:
	# Add print(button) here on first run to confirm names on your device.
	if button == "grip_click":
		_begin_hold()

func _on_right_button_released(button: String) -> void:
	if button == "grip_click":
		_place_brick()

func _begin_hold() -> void:
	if held_brick or not BRICK_SCENES.has(selected_type):
		return
	held_brick = (BRICK_SCENES[selected_type] as PackedScene).instantiate()
	bricks_container.add_child(held_brick)
	(held_brick as Brick).set_ghost(true)

func _process(_delta: float) -> void:
	if held_brick:
		var hand_pos := right_hand.global_position
		var dims: Vector3 = GridSnapper.BRICK_DEFS.get(selected_type, Vector3.ONE)
		held_brick.global_position = GridSnapper.snap(hand_pos, dims)
		held_brick.global_basis = right_hand.global_basis

		# Rotate held brick 90° on thumbstick flick right/left.
		var axes := right_hand.get_vector2("primary")
		if axes.x > 0.7 and not _rotated_this_flick:
			held_brick.rotate_y(deg_to_rad(90.0))
			_rotated_this_flick = true
		elif abs(axes.x) < 0.3:
			_rotated_this_flick = false

	# Desktop orbit camera (only when WebXR is inactive).
	if not webxr_interface or not webxr_interface.is_initialized():
		var cam_pivot := $XROrigin3D
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var vel := Input.get_last_mouse_velocity() * 0.002
			cam_pivot.rotation.y -= vel.x
			cam_pivot.rotation.x = clamp(cam_pivot.rotation.x - vel.y, -1.2, 0.1)

func _place_brick() -> void:
	if not held_brick:
		return
	(held_brick as Brick).set_ghost(false)
	AudioManager.play_place()
	held_brick = null

# ── Desktop fallback (left-click to spawn + place) ───────────────────────────

func _input(event: InputEvent) -> void:
	if webxr_interface and webxr_interface.is_initialized():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not held_brick:
			_begin_hold_desktop()
		else:
			_place_brick()

func _begin_hold_desktop() -> void:
	var cam := $XROrigin3D/XRCamera3D as Camera3D
	var ray := cam.project_ray_normal(get_viewport().get_mouse_position())
	var origin := cam.global_position
	if ray.y >= 0.0:
		return
	var t := -origin.y / ray.y
	var hit := origin + ray * t
	if not BRICK_SCENES.has(selected_type):
		return
	held_brick = (BRICK_SCENES[selected_type] as PackedScene).instantiate()
	bricks_container.add_child(held_brick)
	(held_brick as Brick).set_ghost(true)
	var dims: Vector3 = GridSnapper.BRICK_DEFS.get(selected_type, Vector3.ONE)
	held_brick.global_position = GridSnapper.snap(hit, dims)

# ── HUD signals ──────────────────────────────────────────────────────────────

func _on_brick_selected(type: String) -> void:
	selected_type = type
	if held_brick:
		held_brick.queue_free()
		held_brick = null

func _on_reset() -> void:
	if held_brick:
		held_brick.queue_free()
		held_brick = null
	for child in bricks_container.get_children():
		child.queue_free()
	AudioManager.play_chime()
