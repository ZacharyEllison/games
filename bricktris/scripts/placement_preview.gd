class_name PlacementPreview
extends Node3D

const VALID_COLOR := Color(0.32, 0.82, 0.48, 0.5)
const INVALID_COLOR := Color(0.92, 0.28, 0.22, 0.5)
const SURFACE_EPS := 0.004

var _mesh_instance: MultiMeshInstance3D
var _multimesh: MultiMesh

func _ready() -> void:
	var pitch := BuildLayout.STUD_PITCH
	var cell := BoxMesh.new()
	cell.size = Vector3(pitch * 0.92, 0.002, pitch * 0.92)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = cell
	_multimesh.instance_count = 0

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_mesh_instance = MultiMeshInstance3D.new()
	_mesh_instance.multimesh = _multimesh
	_mesh_instance.material_override = mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

func clear() -> void:
	_multimesh.instance_count = 0

func show_placement(type: String, hit: Vector3, rot_y: float) -> void:
	var data: Dictionary = BuildGrid.preview(type, hit, rot_y)
	var cells: Array = data.get("cells", [])
	if cells.is_empty():
		clear()
		return

	var color := VALID_COLOR if data.get("valid", false) else INVALID_COLOR
	var y: float = data["y"] + SURFACE_EPS
	var origin := GridSnapper.grid_origin_xz
	var pitch := BuildLayout.STUD_PITCH

	_multimesh.instance_count = cells.size()
	for i in cells.size():
		var cell: Vector2i = cells[i]
		var x := origin.x + (cell.x + 0.5) * pitch
		var z := origin.y + (cell.y + 0.5) * pitch
		var xf := Transform3D(Basis.IDENTITY, Vector3(x, y, z))
		_multimesh.set_instance_transform(i, xf)
		_multimesh.set_instance_color(i, color)
