class_name Brick
extends RigidBody3D

# Semi-transparent ghost material applied while held, before placement.
var _ghost_mat: StandardMaterial3D
var _original_mats: Array[Material] = []

func _ready() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.4, 0.7, 1.0, 0.45)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh_child := _get_mesh()
	if mesh_child:
		for i in mesh_child.get_surface_override_material_count():
			_original_mats.append(mesh_child.get_surface_override_material(i))

func set_ghost(is_ghost: bool) -> void:
	var mesh_child := _get_mesh()
	if not mesh_child:
		return
	if is_ghost:
		freeze = true
		collision_layer = 0
		collision_mask = 0
		for i in mesh_child.get_surface_override_material_count():
			mesh_child.set_surface_override_material(i, _ghost_mat)
	else:
		freeze = false
		# Layer 2 = placed bricks; mask 3 = hits layer 1 (desk) + layer 2 (other bricks)
		collision_layer = 2
		collision_mask = 3
		for i in mesh_child.get_surface_override_material_count():
			var mat: Material = _original_mats[i] if i < _original_mats.size() else null
			mesh_child.set_surface_override_material(i, mat)

func _get_mesh() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null
