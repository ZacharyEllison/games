class_name Brick
extends RigidBody3D

var brick_type := ""
var rot_steps := 0

var _ghost_mat: StandardMaterial3D

func _ready() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.4, 0.7, 1.0, 0.45)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disable_shadows_on_node(self)

func set_ghost(is_ghost: bool) -> void:
	if is_ghost:
		freeze = true
		collision_layer = 0
		collision_mask = 0
		_apply_ghost_to_node(self, true)
	else:
		freeze = true
		collision_layer = 2
		collision_mask = 1
		_disable_shadows_on_node(self)

func set_held(is_held: bool) -> void:
	set_ghost(is_held)

func set_placed(type: String, steps: int) -> void:
	brick_type = type
	rot_steps = steps

func set_highlighted(on: bool) -> void:
	if on:
		_apply_mat_to_node(self, _ghost_mat)
	else:
		_disable_shadows_on_node(self)

func _apply_ghost_to_node(node: Node, is_ghost: bool) -> void:
	_apply_mat_to_node(node, _ghost_mat if is_ghost else null)

func _apply_mat_to_node(node: Node, mat) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			for i in mi.get_surface_override_material_count():
				mi.set_surface_override_material(i, mat)
		_apply_mat_to_node(child, mat)

func _disable_shadows_on_node(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src: Material = mi.mesh.surface_get_material(i)
				if src == null:
					src = mi.get_active_material(i)
				if src is StandardMaterial3D:
					var m := (src as StandardMaterial3D).duplicate()
					m.disable_receive_shadows = true
					m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					mi.set_surface_override_material(i, m)
	for child in node.get_children():
		_disable_shadows_on_node(child)

func get_placement_record() -> Dictionary:
	return {
		"type": brick_type,
		"position": global_position,
		"rot_steps": rot_steps,
	}
