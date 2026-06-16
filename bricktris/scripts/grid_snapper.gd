class_name GridSnapper
extends RefCounted

# Measured from Kenney GLB AABB: 1 stud = 0.0795 m, origin at footprint centre.
const STUD_PITCH := 0.0795

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

const BRICK_HEIGHTS := {
	"brick_1x1":       0.114,
	"brick_1x2":       0.114,
	"brick_2x2":       0.114,
	"brick_1x4":       0.114,
	"brick_2x4":       0.114,
	"plate_1x1":       0.05,
	"plate_1x2":       0.05,
	"plate_2x2":       0.05,
	"brick_corner":    0.114,
	"brick_slope_1x2": 0.114,
}

const SEAT_OFFSETS := {
	"brick_1x1":       0.109,
	"brick_1x2":       0.109,
	"brick_2x2":       0.109,
	"brick_1x4":       0.109,
	"brick_2x4":       0.109,
	"plate_1x1":       0.05,
	"plate_1x2":       0.05,
	"plate_2x2":       0.05,
	"brick_corner":    0.109,
	"brick_slope_1x2": 0.109,
}

# Set from the desk node in main.gd so Y always matches the rendered surface.
static var desk_surface_y: float = 0.81
static var grid_origin_xz: Vector2 = Vector2(0.0, -0.8)

static func studs_for(type: String) -> Vector2i:
	return BRICK_STUDS.get(type, Vector2i.ONE)

static func height_for(type: String) -> float:
	return BRICK_HEIGHTS.get(type, 0.114)

static func seat_offset(type: String) -> float:
	return SEAT_OFFSETS.get(type, 0.109)

static func seat_surface_y(type: String, bottom_y: float) -> float:
	return bottom_y + seat_offset(type)

static func rot_steps_from_y(rot_y: float) -> int:
	return int(round(rot_y / (PI * 0.5))) % 4

static func rotated_studs(studs: Vector2i, steps: int) -> Vector2i:
	if steps % 2 == 1:
		return Vector2i(studs.y, studs.x)
	return studs

# Left-most stud column/row index for a footprint.
static func _min_stud_index(rel: float, stud_count: int) -> int:
	return int(floor(rel - stud_count * 0.5 + 0.5))

static func _axis_center(origin: float, min_ix: int, stud_count: int) -> float:
	return origin + (min_ix + stud_count * 0.5) * STUD_PITCH

# Snap brick origin so every stud peg sits on a cell centre (not a line intersection).
static func snap_xz(hit: Vector3, studs: Vector2i) -> Vector2:
	var rel_x := (hit.x - grid_origin_xz.x) / STUD_PITCH
	var rel_z := (hit.z - grid_origin_xz.y) / STUD_PITCH
	var min_ix := _min_stud_index(rel_x, studs.x)
	var min_iz := _min_stud_index(rel_z, studs.y)
	return Vector2(
		_axis_center(grid_origin_xz.x, min_ix, studs.x),
		_axis_center(grid_origin_xz.y, min_iz, studs.y)
	)

static func footprint_indices(center_xz: Vector2, studs: Vector2i) -> Array[Vector2i]:
	var rel_x := (center_xz.x - grid_origin_xz.x) / STUD_PITCH
	var rel_z := (center_xz.y - grid_origin_xz.y) / STUD_PITCH
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
	grid_origin_xz = Vector2(desk.global_position.x, desk.global_position.z)
	desk_surface_y = desk.global_position.y + 0.01
