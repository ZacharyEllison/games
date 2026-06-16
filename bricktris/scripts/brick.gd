class_name Brick
extends RigidBody3D

var _ghost_mat: StandardMaterial3D

func _ready() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.4, 0.7, 1.0, 0.45)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func set_ghost(is_ghost: bool) -> void:
	if is_ghost:
		freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		freeze = false
		collision_layer = 2
		collision_mask = 3  # collides with desk (layer 1) and other bricks (layer 2)
	# Apply to all MeshInstance3D nodes in the subtree (GLB nests them one level deep)
	_apply_ghost_to_node(self, is_ghost)

# Only changes material, does not touch physics — safe for palette preview bricks.
func set_highlighted(on: bool) -> void:
	_apply_mat_to_node(self, _ghost_mat if on else null)

func _apply_ghost_to_node(node: Node, is_ghost: bool) -> void:
	_apply_mat_to_node(node, _ghost_mat if is_ghost else null)

func _apply_mat_to_node(node: Node, mat) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			for i in mi.get_surface_override_material_count():
				mi.set_surface_override_material(i, mat)
		_apply_mat_to_node(child, mat)
