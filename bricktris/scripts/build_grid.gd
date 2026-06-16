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

static func seat_at(cell: Vector2i) -> float:
	var k := _key(cell)
	if _seats.has(k):
		return _seats[k]
	return -1.0

static func support_run_x(click_ix: int, click_iz: int) -> Vector2i:
	var seat_y := seat_at(Vector2i(click_ix, click_iz))
	if seat_y < 0.0:
		return Vector2i(-1, -1)
	var min_ix := click_ix
	var max_ix := click_ix
	while min_ix > 0 and seat_at(Vector2i(min_ix - 1, click_iz)) == seat_y:
		min_ix -= 1
	while max_ix + 1 < BuildLayout.DESK_STUDS and seat_at(Vector2i(max_ix + 1, click_iz)) == seat_y:
		max_ix += 1
	return Vector2i(min_ix, max_ix)

static func support_run_z(click_ix: int, click_iz: int) -> Vector2i:
	var seat_y := seat_at(Vector2i(click_ix, click_iz))
	if seat_y < 0.0:
		return Vector2i(-1, -1)
	var min_iz := click_iz
	var max_iz := click_iz
	while min_iz > 0 and seat_at(Vector2i(click_ix, min_iz - 1)) == seat_y:
		min_iz -= 1
	while max_iz + 1 < BuildLayout.DESK_STUDS and seat_at(Vector2i(click_ix, max_iz + 1)) == seat_y:
		max_iz += 1
	return Vector2i(min_iz, max_iz)

static func placement(type: String, hit: Vector3, rot_y: float) -> Dictionary:
	var steps := GridSnapper.rot_steps_from_y(rot_y)
	var studs := GridSnapper.rotated_studs(GridSnapper.studs_for(type), steps)
	var xz := GridSnapper.snap_xz(hit, studs)
	if not GridSnapper.footprint_fits_desk(xz, studs):
		return {}
	var y := bottom_y(type, xz, steps)
	return {
		"position": Vector3(xz.x, y, xz.y),
		"rot_y": GridSnapper.snap_rotation(rot_y),
		"rot_steps": steps,
	}

static func preview(type: String, hit: Vector3, rot_y: float) -> Dictionary:
	var steps := GridSnapper.rot_steps_from_y(rot_y)
	var studs := GridSnapper.rotated_studs(GridSnapper.studs_for(type), steps)
	var xz := GridSnapper.snap_xz(hit, studs)
	var valid := GridSnapper.footprint_fits_desk(xz, studs)
	var y := bottom_y(type, xz, steps) if valid else GridSnapper.desk_surface_y
	return {
		"cells": GridSnapper.footprint_indices(xz, studs),
		"y": y,
		"valid": valid,
	}
