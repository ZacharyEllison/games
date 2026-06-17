class_name Brick
extends RigidBody3D

var brick_type := ""
var rot_steps := 0
var is_thrown := false
var _min_indices := Vector2i.ZERO
var throw_age := 0.0

var _ghost_mat: StandardMaterial3D

func _ready() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.45, 0.75, 1.0, 0.5)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_apply_placed_look(self)

func set_ghost(is_ghost: bool) -> void:
	if is_ghost:
		freeze = true
		collision_layer = 0
		collision_mask = 0
		_apply_mat_to_node(self, _ghost_mat)
	else:
		freeze = true
		collision_layer = 2
		collision_mask = 1
		_apply_placed_look(self)

func set_held(is_held: bool) -> void:
	is_thrown = false
	throw_age = 0.0
	set_ghost(is_held)

func begin_throw(lin_vel: Vector3, ang_vel: Vector3) -> void:
	is_thrown = true
	throw_age = 0.0
	freeze = false
	collision_layer = 2
	collision_mask = 3
	contact_monitor = true
	max_contacts_reported = 4
	linear_velocity = lin_vel
	angular_velocity = ang_vel
	_apply_placed_look(self)

func tick_throw(delta: float) -> void:
	if is_thrown:
		throw_age += delta

func set_placed(type: String, steps: int, min_indices: Vector2i = Vector2i.ZERO) -> void:
	brick_type = type
	rot_steps = steps
	_min_indices = min_indices

func set_highlighted(on: bool) -> void:
	if on:
		_apply_mat_to_node(self, _ghost_mat)
	else:
		_apply_placed_look(self)

func _apply_placed_look(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src: Material = mi.mesh.surface_get_material(i)
				if src == null:
					src = mi.get_active_material(i)
				mi.set_surface_override_material(i, BrickMaterials.placed_from(src))
	for child in node.get_children():
		_apply_placed_look(child)

func _apply_mat_to_node(node: Node, mat) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			for i in mi.get_surface_override_material_count():
				mi.set_surface_override_material(i, mat)
		_apply_mat_to_node(child, mat)

func get_placement_record() -> Dictionary:
	return {
		"type": brick_type,
		"position": global_position,
		"rot_steps": rot_steps,
		"min_indices": _min_indices,
	}
