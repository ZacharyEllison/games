class_name BuildGrid
extends RefCounted

# Per stud-column seat surface Y (where the next piece's bottom pegs connect).
static var _seats: Dictionary = {}

static func clear() -> void:
	_seats.clear()

# Height for a new brick: rests on the highest support under any stud in its footprint.
# A 2x4 spanning two columns at different heights sits level on the taller column.
static func bottom_y(type: String, center_xz: Vector2, rot_steps: int) -> float:
	var studs := GridSnapper.rotated_studs(GridSnapper.studs_for(type), rot_steps)
	var base := GridSnapper.desk_surface_y
	for cell in GridSnapper.footprint_indices(center_xz, studs):
		var key := _key(cell)
		if _seats.has(key):
			base = maxf(base, _seats[key])
	return base

static func register_placed(type: String, pos: Vector3, rot_steps: int) -> void:
	var studs := GridSnapper.rotated_studs(GridSnapper.studs_for(type), rot_steps)
	var xz := Vector2(pos.x, pos.z)
	var seat := GridSnapper.seat_surface_y(type, pos.y)
	for cell in GridSnapper.footprint_indices(xz, studs):
		var key := _key(cell)
		if _seats.has(key):
			_seats[key] = maxf(_seats[key], seat)
		else:
			_seats[key] = seat

static func rebuild(placements: Array) -> void:
	clear()
	for p in placements:
		register_placed(p["type"], p["position"], p["rot_steps"])

static func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func placement(type: String, hit: Vector3, rot_y: float) -> Dictionary:
	var steps := GridSnapper.rot_steps_from_y(rot_y)
	var studs := GridSnapper.rotated_studs(GridSnapper.studs_for(type), steps)
	var xz := GridSnapper.snap_xz(hit, studs)
	var y := bottom_y(type, xz, steps)
	return {
		"position": Vector3(xz.x, y, xz.y),
		"rot_y": GridSnapper.snap_rotation(rot_y),
		"rot_steps": steps,
	}
