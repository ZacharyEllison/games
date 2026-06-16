class_name GridSnapper
extends RefCounted

# Stud footprint in mesh space: X = width (studs), Y = depth (studs).
# Kenney GLBs orient 1xN bricks with the long axis along +X.
const BRICK_STUDS := {
	"brick_1x1":       Vector2i(1, 1),
	"brick_1x2":       Vector2i(2, 1),
	"brick_2x2":       Vector2i(2, 2),
	"brick_1x4":       Vector2i(4, 1),
	"brick_2x4":       Vector2i(4, 2),
	"plate_1x1":       Vector2i(1, 1),
	"plate_1x2":       Vector2i(2, 1),
	"plate_2x2":       Vector2i(2, 2),
	"brick_corner":    Vector2i(2, 2),
	"brick_slope_1x2": Vector2i(2, 1),
}

static var desk_surface_y: float = 0.81
static var grid_origin_xz: Vector2 = Vector2.ZERO

static func studs_for(type: String) -> Vector2i:
	return BRICK_STUDS.get(type, Vector2i.ONE)

static func height_for(type: String) -> float:
	return BuildLayout.full_height(type)

static func seat_offset(type: String) -> float:
	return BuildLayout.seat_height(type)

static func seat_surface_y(type: String, bottom_y: float) -> float:
	return bottom_y + seat_offset(type)

static func rot_steps_from_y(rot_y: float) -> int:
	return int(round(rot_y / (PI * 0.5))) % 4

static func rotated_studs(studs: Vector2i, steps: int) -> Vector2i:
	if steps % 2 == 1:
		return Vector2i(studs.y, studs.x)
	return studs

static func _stud_cell(rel: float) -> int:
	return int(round(rel - 0.5))

static func _min_stud_index(rel: float, _stud_count: int) -> int:
	# Anchor the clicked stud column/row as the footprint minimum.
	return _stud_cell(rel)

static func _axis_center(origin: float, min_ix: int, stud_count: int) -> float:
	return origin + (min_ix + stud_count * 0.5) * BuildLayout.STUD_PITCH

static func snap_xz(hit: Vector3, studs: Vector2i) -> Vector2:
	var pitch := BuildLayout.STUD_PITCH
	var rel_x := (hit.x - grid_origin_xz.x) / pitch
	var rel_z := (hit.z - grid_origin_xz.y) / pitch
	var min_ix := _min_stud_index(rel_x, studs.x)
	var min_iz := _min_stud_index(rel_z, studs.y)
	return Vector2(
		_axis_center(grid_origin_xz.x, min_ix, studs.x),
		_axis_center(grid_origin_xz.y, min_iz, studs.y)
	)

static func footprint_indices(center_xz: Vector2, studs: Vector2i) -> Array[Vector2i]:
	var pitch := BuildLayout.STUD_PITCH
	var rel_x := (center_xz.x - grid_origin_xz.x) / pitch
	var rel_z := (center_xz.y - grid_origin_xz.y) / pitch
	var min_ix := _min_stud_index(rel_x, studs.x)
	var min_iz := _min_stud_index(rel_z, studs.y)
	var cells: Array[Vector2i] = []
	for ix in studs.x:
		for iz in studs.y:
			cells.append(Vector2i(min_ix + ix, min_iz + iz))
	return cells

static func snap_rotation(rot_y: float) -> float:
	return float(rot_steps_from_y(rot_y)) * (PI * 0.5)

static func configure_from_desk(desk: Node3D) -> void:
	grid_origin_xz = BuildLayout.grid_origin_xz(desk)
	desk_surface_y = BuildLayout.desk_top_y(desk)
	_sync_desk_shader(desk)

static func _sync_desk_shader(desk: Node3D) -> void:
	var mesh := desk.get_node_or_null("DeskMesh") as MeshInstance3D
	if not mesh:
		return
	var mat := mesh.get_surface_override_material(0) as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("grid_origin", grid_origin_xz)
	mat.set_shader_parameter("cell_size", BuildLayout.STUD_PITCH)
	mat.set_shader_parameter("stud_radius", BuildLayout.STUD_DOT_RADIUS)
