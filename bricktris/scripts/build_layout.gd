class_name BuildLayout
extends RefCounted

# Kenney bevel-hq brick mesh: one stud along an axis.
const STUD_PITCH := 0.0795

const BRICK_HEIGHT := 0.114
const PLATE_HEIGHT := 0.05
const BRICK_SEAT := 0.096
const PLATE_SEAT := 0.032

const DESK_STUDS := 10
const DESK_TOP_EPS := 0.01
const DESK_EXTENT := DESK_STUDS * STUD_PITCH
const DESK_HALF_EXTENT := DESK_EXTENT * 0.5

const DESK_TOP_Y := 0.8
const SEATED_CAM_Z := 0.3
const DESK_NEAR_MARGIN := STUD_PITCH * 5.0
const VR_PALETTE_GAP := 0.0
const VR_PALETTE_LIFT := DESK_TOP_EPS

const PALETTE_X_SPACING := STUD_PITCH * 4.5
const PALETTE_Z_SPACING := DESK_EXTENT / 4.0
const PALETTE_BRICK_SCALE := 0.85
const PALETTE_GRAB_RADIUS := STUD_PITCH * 2.25
const VR_GRAB_RADIUS := STUD_PITCH * 1.75
const STUD_DOT_RADIUS := STUD_PITCH * 0.16
const THROW_SPEED_THRESHOLD := STUD_PITCH * 7.0

static func desk_extent() -> float:
	return DESK_EXTENT

static func desk_half_extent() -> float:
	return DESK_HALF_EXTENT

static func desk_top_y(desk: Node3D) -> float:
	return desk.global_position.y + DESK_TOP_EPS

static func desk_position() -> Vector3:
	var z := SEATED_CAM_Z - DESK_NEAR_MARGIN - DESK_HALF_EXTENT
	return Vector3(0.0, DESK_TOP_Y, z)

static func vr_palette_position(desk_pos: Vector3) -> Vector3:
	# Origin at the grid's front-right corner; slots run along -Z (down the edge).
	var x := desk_pos.x + DESK_HALF_EXTENT + VR_PALETTE_GAP
	var z := desk_pos.z + DESK_HALF_EXTENT
	return Vector3(x, desk_pos.y + VR_PALETTE_LIFT, z)

static func grid_origin_xz(desk: Node3D) -> Vector2:
	var half := DESK_HALF_EXTENT
	var p := desk.global_position
	return Vector2(p.x - half, p.z - half)

static func stud_world_xz(origin: Vector2, cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * STUD_PITCH

static func palette_col_spacing() -> float:
	return PALETTE_X_SPACING

static func palette_row_spacing() -> float:
	return PALETTE_Z_SPACING

static func palette_grab_radius() -> float:
	return PALETTE_GRAB_RADIUS

static func vr_grab_radius() -> float:
	return VR_GRAB_RADIUS

static func full_height(type: String) -> float:
	return PLATE_HEIGHT if type.begins_with("plate_") else BRICK_HEIGHT

static func seat_height(type: String) -> float:
	return PLATE_SEAT if type.begins_with("plate_") else BRICK_SEAT
