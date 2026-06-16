extends Node3D

var webxr_interface: WebXRInterface
var _in_vr := false
var _xr_checks := 0
var _ar_supported := false
var _vr_supported := false
var _saved_bg_mode: int
var _saved_bg_color: Color
var _use_passthrough := false

var held_brick: Node3D = null
var _grabbed_type := ""
var _held_rot_steps := 0
var _rotated_this_flick := false
var _active_hand: XRController3D = null

var _placed_bricks: Array = []

const RAY_MASK := 3  # desk (1) + placed bricks (2)
const GRAB_RADIUS := BuildLayout.VR_GRAB_RADIUS
const THROW_SPEED_THRESHOLD := BuildLayout.THROW_SPEED_THRESHOLD
const THROW_VELOCITY_SCALE := 1.45
const THROW_ANGULAR_SCALE := 0.9
const THROW_DESPAWN_SECONDS := BuildLayout.THROW_DESPAWN_SECONDS
const VELOCITY_SAMPLES := 4

var _hand_prev_pos := Vector3.ZERO
var _hand_prev_basis := Basis.IDENTITY
var _hand_velocity := Vector3.ZERO
var _hand_angular_velocity := Vector3.ZERO
var _vel_samples: Array[Vector3] = []
var _thrown_bricks: Array[Brick] = []

var _cam_yaw := 0.0
var _cam_pitch := 0.52
var _cam_dist := DesktopCamera.ORBIT_DISTANCE
var _cam_ortho := false
var _cam_ortho_size := DesktopCamera.ORTHO_SIZE
var _cam_preset := DesktopCamera.Preset.ORBIT
var _cam_orbit_drag := false

@onready var _placement_preview: Node3D = $PlacementPreview
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var right_hand_mesh: MeshInstance3D = $XROrigin3D/RightHand/RightHandMesh
@onready var left_hand_mesh: MeshInstance3D = $XROrigin3D/LeftHand/LeftHandMesh
@onready var cam: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var bricks_container: Node3D = $Bricks
@onready var hud: HUD = $HUD
@onready var brick_palette: BrickPalette = $BrickPalette
@onready var desk: StaticBody3D = $Desk
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $DirectionalLight3D

func _ready() -> void:
	_layout_workspace()
	_configure_scene_lighting()
	var env := world_env.environment
	_saved_bg_mode = env.background_mode
	_saved_bg_color = env.background_color
	right_hand.button_pressed.connect(_on_right_button_pressed)
	right_hand.button_released.connect(_on_right_button_released)
	left_hand.button_pressed.connect(_on_left_button_pressed)
	left_hand.button_released.connect(_on_left_button_released)
	hud.reset_requested.connect(_on_reset)
	hud.enter_vr_requested.connect(_on_enter_vr)
	hud.view_preset_selected.connect(_on_desktop_view_preset)
	_set_hand_mesh_visible(false)
	brick_palette.show()
	_init_desktop_camera()
	_init_webxr()

func _init_webxr() -> void:
	webxr_interface = XRServer.find_interface("WebXR") as WebXRInterface
	if not webxr_interface:
		hud.set_vr_status("desktop")
		return
	webxr_interface.session_supported.connect(_webxr_session_supported)
	webxr_interface.session_started.connect(_webxr_session_started)
	webxr_interface.session_ended.connect(_webxr_session_ended)
	webxr_interface.session_failed.connect(_webxr_session_failed)
	webxr_interface.is_session_supported("immersive-ar")
	webxr_interface.is_session_supported("immersive-vr")

func _webxr_session_supported(session_mode: String, supported: bool) -> void:
	if session_mode == "immersive-ar":
		_ar_supported = supported
	elif session_mode == "immersive-vr":
		_vr_supported = supported
	_xr_checks += 1
	if _xr_checks < 2:
		return
	if _ar_supported or _vr_supported:
		hud.set_vr_status("supported")
	else:
		hud.set_vr_status("desktop")

func _on_enter_vr() -> void:
	if not webxr_interface:
		return
	# Prefer AR passthrough; fall back to opaque VR.
	_use_passthrough = true
	webxr_interface.session_mode = "immersive-ar"
	webxr_interface.requested_reference_space_types = "bounded-floor, local-floor, local"
	webxr_interface.required_features = "local-floor"
	webxr_interface.optional_features = "bounded-floor, hand-tracking, dom-overlay"
	if not webxr_interface.initialize():
		_use_passthrough = false
		webxr_interface.session_mode = "immersive-vr"
		webxr_interface.optional_features = "bounded-floor, hand-tracking"
		if not webxr_interface.initialize():
			OS.alert("Failed to start WebXR session")

func _webxr_session_started() -> void:
	_in_vr = true
	_reset_hand_tracking()
	DesktopCamera.reset_rig(xr_origin, cam)
	_layout_workspace()
	_use_passthrough = webxr_interface.session_mode == "immersive-ar"
	_set_passthrough(_use_passthrough)
	_set_hand_mesh_visible(true)
	brick_palette.show()
	get_viewport().use_xr = true
	hud.on_xr_started()
	webxr_interface.squeezestart.connect(_on_squeeze_start)
	webxr_interface.squeezeend.connect(_on_squeeze_end)
	webxr_interface.visibility_state_changed.connect(_on_visibility_changed)

func _set_passthrough(on: bool) -> void:
	var env := world_env.environment
	if on:
		get_viewport().transparent_bg = true
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0, 0)
	else:
		get_viewport().transparent_bg = false
		env.background_mode = _saved_bg_mode
		env.background_color = _saved_bg_color

func _set_hand_mesh_visible(visible: bool) -> void:
	right_hand_mesh.visible = visible
	left_hand_mesh.visible = visible

func _hand_for_input_source(input_source_id: int) -> XRController3D:
	match input_source_id:
		0:
			return left_hand
		1:
			return right_hand
	return null

func _vr_hand() -> XRController3D:
	if not _in_vr:
		return right_hand
	if held_brick and _active_hand:
		return _active_hand
	return _nearest_live_hand_to(brick_palette.global_position)

func _hand_is_live(hand: XRController3D) -> bool:
	return hand.get_is_active()

func _nearest_live_hand_to(target: Vector3) -> XRController3D:
	var best: XRController3D = right_hand
	var best_dist := INF
	for hand in [left_hand, right_hand]:
		if not _hand_is_live(hand):
			continue
		var d: float = hand.global_position.distance_squared_to(target)
		if d < best_dist:
			best_dist = d
			best = hand
	return best

func _layout_workspace() -> void:
	desk.global_position = BuildLayout.desk_position()
	GridSnapper.configure_from_desk(desk)
	brick_palette.global_position = BuildLayout.vr_palette_position(desk.global_position)
	brick_palette.rotation = Vector3.ZERO

func _reset_hand_tracking() -> void:
	_hand_prev_pos = Vector3.ZERO
	_hand_prev_basis = Basis.IDENTITY
	_hand_velocity = Vector3.ZERO
	_hand_angular_velocity = Vector3.ZERO
	_vel_samples.clear()

func _configure_scene_lighting() -> void:
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = BuildLayout.desk_extent() * 1.5
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.1
	sun.shadow_blur = 1.2
	sun.light_energy = 1.2
	sun.light_specular = 0.4
	var env := world_env.environment
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

func _webxr_session_ended() -> void:
	_in_vr = false
	_set_hand_mesh_visible(false)
	_set_passthrough(false)
	get_viewport().use_xr = false
	hud.on_xr_ended()
	_init_desktop_camera()
	_apply_desktop_view_preset(_cam_preset)

func _webxr_session_failed(message: String) -> void:
	OS.alert("WebXR failed: " + message)
	hud.set_vr_status("supported")

func _on_visibility_changed() -> void:
	get_tree().paused = (webxr_interface.visibility_state != "visible")

func _on_squeeze_start(input_source_id: int) -> void:
	var hand := _hand_for_input_source(input_source_id)
	if hand:
		_try_grab(hand)

func _on_squeeze_end(input_source_id: int) -> void:
	var hand := _hand_for_input_source(input_source_id)
	if hand and hand == _active_hand:
		_vr_release_brick()

func _on_right_button_pressed(button: String) -> void:
	_on_hand_button_pressed(right_hand, button, true)

func _on_right_button_released(button: String) -> void:
	_on_hand_button_pressed(right_hand, button, false)

func _on_left_button_pressed(button: String) -> void:
	_on_hand_button_pressed(left_hand, button, true)

func _on_left_button_released(button: String) -> void:
	_on_hand_button_pressed(left_hand, button, false)

func _on_hand_button_pressed(hand: XRController3D, button: String, pressed: bool) -> void:
	if button != "grip_click":
		return
	if pressed:
		_try_grab(hand)
	elif hand == _active_hand:
		_vr_release_brick()

func _try_grab(hand: XRController3D) -> void:
	if held_brick:
		return
	var hand_pos := hand.global_position
	var palette_hit: Dictionary = brick_palette.query_nearest(hand_pos)
	var placed: Brick = _nearest_placed_brick(hand_pos)
	var palette_dist: float = palette_hit["distance"]
	var placed_dist: float = placed.global_position.distance_to(hand_pos) if placed else INF

	if placed and placed_dist <= palette_dist and placed_dist < GRAB_RADIUS:
		_grab_placed_brick(placed)
	elif not palette_hit["type"].is_empty():
		_spawn_from_palette(palette_hit["type"])
	if held_brick:
		_active_hand = hand
		_reset_hand_tracking()

func _spawn_from_palette(type: String) -> void:
	_grabbed_type = type
	var scene: PackedScene = BrickPalette.BRICK_SCENES.get(type)
	if not scene:
		return
	held_brick = scene.instantiate()
	bricks_container.add_child(held_brick)
	_held_rot_steps = 0
	var brick := held_brick as Brick
	brick.set_placed(type, 0)
	brick.set_held(true)

func _grab_placed_brick(brick: Brick) -> void:
	if brick.brick_type.is_empty():
		return
	_grabbed_type = brick.brick_type
	_held_rot_steps = brick.rot_steps
	held_brick = brick
	if _placed_bricks.has(brick):
		_placed_bricks.erase(brick)
		_rebuild_grid()
	(brick as Brick).set_held(true)

func _nearest_placed_brick(hand_pos: Vector3) -> Brick:
	var best: Brick = null
	var best_dist := GRAB_RADIUS
	for node in _placed_bricks:
		if not is_instance_valid(node) or not node is Brick:
			continue
		var brick := node as Brick
		var d: float = brick.global_position.distance_to(hand_pos)
		if d < best_dist:
			best_dist = d
			best = brick
	for node in bricks_container.get_children():
		if not is_instance_valid(node) or not node is Brick:
			continue
		var brick := node as Brick
		if brick == held_brick or brick.is_thrown or _placed_bricks.has(brick):
			continue
		if not brick.brick_type.is_empty():
			var d: float = brick.global_position.distance_to(hand_pos)
			if d < best_dist:
				best_dist = d
				best = brick
	return best

func _vr_release_brick() -> void:
	if not held_brick:
		return
	var throw_speed := _release_velocity().length()
	if throw_speed >= THROW_SPEED_THRESHOLD:
		_throw_held(_release_velocity(), _release_angular_velocity())
		return
	var drop_dir := Vector3.DOWN if not _in_vr else -_vr_hand().global_transform.basis.y
	var hand := _vr_hand()
	var hit := _raycast_surface(hand.global_position, drop_dir)
	if hit == Vector3.INF:
		hit = hand.global_position
	var rot_y := _held_rot_y()
	var p: Dictionary = BuildGrid.placement(_grabbed_type, hit, rot_y)
	if p.is_empty():
		_clear_placement_preview()
		return
	_finalize_placement(held_brick as Brick, _grabbed_type, rot_y, p)
	_active_hand = null

func _clear_placement_preview() -> void:
	if _placement_preview:
		_placement_preview.clear()

func _held_rot_y() -> float:
	return float(_held_rot_steps) * (PI * 0.5)

func _release_velocity() -> Vector3:
	if _vel_samples.is_empty():
		return _hand_velocity * THROW_VELOCITY_SCALE
	var avg := Vector3.ZERO
	for v in _vel_samples:
		avg += v
	return (avg / float(_vel_samples.size())) * THROW_VELOCITY_SCALE

func _release_angular_velocity() -> Vector3:
	return _hand_angular_velocity * THROW_ANGULAR_SCALE

func _throw_held(lin_vel: Vector3, ang_vel: Vector3) -> void:
	var brick := held_brick as Brick
	held_brick = null
	_active_hand = null
	_clear_placement_preview()
	brick.begin_throw(lin_vel, ang_vel)
	_thrown_bricks.append(brick)

func _despawn_thrown(brick: Brick, play_sound: bool = true) -> void:
	if is_instance_valid(brick):
		brick.queue_free()
	_thrown_bricks.erase(brick)
	if play_sound:
		AudioManager.play_chime()

func _process(_delta: float) -> void:
	if _in_vr:
		_process_vr(_delta)
	else:
		_process_desktop(_delta)

func _physics_process(delta: float) -> void:
	_update_thrown_bricks(delta)

func _track_hand_motion(hand_pos: Vector3, delta: float, hand_basis: Basis) -> void:
	if _hand_prev_pos != Vector3.ZERO:
		var sample := (hand_pos - _hand_prev_pos) / maxf(delta, 0.001)
		_hand_velocity = sample
		_vel_samples.append(sample)
		while _vel_samples.size() > VELOCITY_SAMPLES:
			_vel_samples.pop_front()
	if hand_basis != Basis.IDENTITY and _hand_prev_basis != Basis.IDENTITY:
		var delta_basis := _hand_prev_basis.inverse() * hand_basis
		var euler := delta_basis.get_euler()
		_hand_angular_velocity = euler / maxf(delta, 0.001)
	_hand_prev_pos = hand_pos
	if hand_basis != Basis.IDENTITY:
		_hand_prev_basis = hand_basis

func _process_vr(delta: float) -> void:
	var hand := _vr_hand()
	var hand_pos := hand.global_position
	var hand_basis := hand.global_transform.basis
	_track_hand_motion(hand_pos, delta, hand_basis)

	if held_brick:
		held_brick.global_position = hand_pos
		held_brick.rotation = Vector3(0, _held_rot_y(), 0)
		var axes := hand.get_vector2("primary")
		if not _rotated_this_flick:
			if axes.x > 0.7:
				_held_rot_steps = (_held_rot_steps + 1) % 4
				_rotated_this_flick = true
			elif axes.x < -0.7:
				_held_rot_steps = (_held_rot_steps + 3) % 4
				_rotated_this_flick = true
		elif abs(axes.x) < 0.3:
			_rotated_this_flick = false
	else:
		brick_palette.update_highlight(hand_pos)

func _update_thrown_bricks(delta: float) -> void:
	var to_despawn: Array[Brick] = []
	for brick in _thrown_bricks:
		if not is_instance_valid(brick):
			to_despawn.append(brick)
			continue
		brick.tick_throw(delta)
		if brick.throw_age >= THROW_DESPAWN_SECONDS:
			to_despawn.append(brick)
	for brick in to_despawn:
		_despawn_thrown(brick)

func _process_desktop(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var over_ui := hud.is_pointer_over_ui(mouse)
	if not over_ui or held_brick:
		var hand_pos := _desktop_hand_pos()
		right_hand.global_position = hand_pos
		_track_hand_motion(hand_pos, delta, Basis.IDENTITY)
		if held_brick:
			held_brick.global_position = hand_pos
			held_brick.rotation = Vector3(0, _held_rot_y(), 0)
			_update_desktop_placement_preview()
		elif not over_ui:
			brick_palette.update_highlight(hand_pos)
			_clear_placement_preview()
	else:
		_clear_placement_preview()
	if _cam_orbit_drag:
		var vel := Input.get_last_mouse_velocity() * 0.003
		_cam_yaw -= vel.x
		_cam_pitch = clampf(_cam_pitch - vel.y, 0.08, 1.56)
		_cam_preset = DesktopCamera.Preset.ORBIT
		hud.set_active_view(_cam_preset)
		_apply_desktop_camera()

func _init_desktop_camera() -> void:
	_set_hand_mesh_visible(false)
	_reset_hand_tracking()
	xr_origin.global_position = Vector3.ZERO
	xr_origin.global_rotation = Vector3.ZERO
	_apply_desktop_view_preset(DesktopCamera.Preset.ORBIT)

func _apply_desktop_view_preset(preset: int) -> void:
	var data: Dictionary = DesktopCamera.preset(preset)
	_cam_preset = preset
	_cam_yaw = data["yaw"]
	_cam_pitch = data["pitch"]
	_cam_dist = data["dist"]
	_cam_ortho = data["ortho"]
	if data.has("ortho_size"):
		_cam_ortho_size = data["ortho_size"]
	_apply_desktop_camera()

func _apply_desktop_camera() -> void:
	DesktopCamera.apply(cam, desk, _cam_yaw, _cam_pitch, _cam_dist, _cam_ortho, _cam_ortho_size)

func _on_desktop_view_preset(preset: int) -> void:
	_apply_desktop_view_preset(preset)

func _zoom_desktop_camera(delta: float) -> void:
	if _cam_ortho:
		_cam_ortho_size = clampf(_cam_ortho_size + delta, DesktopCamera.MIN_ORTHO, DesktopCamera.MAX_ORTHO)
	else:
		_cam_dist = clampf(_cam_dist + delta, DesktopCamera.MIN_DISTANCE, DesktopCamera.MAX_DISTANCE)
	_apply_desktop_camera()

func _desktop_hand_pos() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var lift := BuildLayout.BRICK_HEIGHT * 0.75
	var hit := _raycast_surface(origin, dir)
	if hit != Vector3.INF:
		return hit + Vector3(0, lift, 0)
	var hand_y := desk.global_position.y + BuildLayout.VR_PALETTE_LIFT
	if absf(dir.y) > 0.0001:
		var t := (hand_y - origin.y) / dir.y
		if t > 0.05:
			return origin + dir * t
	return origin + dir * 0.55

func _update_desktop_placement_preview() -> void:
	if _in_vr or not held_brick or not _placement_preview:
		return
	var hit := _raycast_surface(right_hand.global_position, Vector3.DOWN)
	if hit == Vector3.INF:
		hit = right_hand.global_position
	_placement_preview.show_placement(_grabbed_type, hit, _held_rot_y())

# Raycast against desk + placed bricks so stacking targets the surface under the cursor.
func _raycast_surface(from: Vector3, dir: Vector3) -> Vector3:
	if dir.length_squared() < 0.0001:
		return Vector3.INF
	dir = dir.normalized()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 20.0)
	query.collision_mask = RAY_MASK
	var result := space.intersect_ray(query)
	if not result.is_empty():
		return result.position
	if dir.y >= -0.001:
		return Vector3.INF
	var t := -(from.y - GridSnapper.desk_surface_y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return from + dir * t

func _input(event: InputEvent) -> void:
	if _in_vr:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and held_brick:
			_held_rot_steps = (_held_rot_steps + 1) % 4
			_update_desktop_placement_preview()
		elif event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
			_desktop_undo()

func _unhandled_input(event: InputEvent) -> void:
	if _in_vr:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if hud.is_pointer_over_ui(get_viewport().get_mouse_position()):
				return
			if event.pressed:
				_try_grab(right_hand)
			else:
				_vr_release_brick()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cam_orbit_drag = event.pressed
		elif event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_zoom_desktop_camera(-BuildLayout.STUD_PITCH * 0.75)
				MOUSE_BUTTON_WHEEL_DOWN:
					_zoom_desktop_camera(BuildLayout.STUD_PITCH * 0.75)

func _finalize_placement(brick: Brick, type: String, rot_y: float, preset: Dictionary = {}) -> void:
	var p: Dictionary = preset if not preset.is_empty() else BuildGrid.placement(type, brick.global_position, rot_y)
	if p.is_empty():
		if is_instance_valid(brick):
			brick.queue_free()
		return
	brick.global_position = p["position"]
	brick.rotation = Vector3(0, p["rot_y"], 0)
	brick.set_placed(type, p["rot_steps"])
	brick.set_ghost(false)
	BuildGrid.register_placed(type, p["position"], p["rot_steps"])
	_placed_bricks.append(brick)
	held_brick = null
	_clear_placement_preview()
	AudioManager.play_place()

func _desktop_undo() -> void:
	if _placed_bricks.is_empty():
		return
	var last: Node = _placed_bricks.pop_back()
	if is_instance_valid(last):
		last.queue_free()
	_rebuild_grid()

func _rebuild_grid() -> void:
	var records: Array = []
	for b in _placed_bricks:
		if is_instance_valid(b) and b is Brick:
			records.append((b as Brick).get_placement_record())
	BuildGrid.rebuild(records)

func _on_reset() -> void:
	_clear_placement_preview()
	_active_hand = null
	if held_brick:
		held_brick.queue_free()
		held_brick = null
	for brick in _thrown_bricks.duplicate():
		_despawn_thrown(brick, false)
	_thrown_bricks.clear()
	_placed_bricks.clear()
	BuildGrid.clear()
	for child in bricks_container.get_children():
		child.queue_free()
	AudioManager.play_chime()
