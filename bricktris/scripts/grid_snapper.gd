class_name GridSnapper
extends RefCounted

# All bricks are scaled by BRICK_SCALE so 1 Kenney stud = 0.08m in world space.
const BRICK_SCALE := 0.08
const CELL_SIZE   := 0.08   # horizontal grid pitch in metres

# XZ footprint (studs) and Y height (raw Kenney units) per brick type.
# The Y value is the unscaled collision-shape half-extent used for precise floor offset.
const BRICK_DEFS := {
	"brick_1x1":       Vector3(1, 1, 1),
	"brick_1x2":       Vector3(1, 1, 2),
	"brick_2x2":       Vector3(2, 1, 2),
	"brick_1x4":       Vector3(1, 1, 4),
	"brick_2x4":       Vector3(2, 1, 4),
	"plate_1x1":       Vector3(1, 0.4, 1),
	"plate_1x2":       Vector3(1, 0.4, 2),
	"plate_2x2":       Vector3(2, 0.4, 2),
	"brick_corner":    Vector3(1, 1, 1),
	"brick_slope_1x2": Vector3(1, 1, 2),
}

# Actual full heights in Kenney units (from each brick scene's BoxShape3D size.y).
const BRICK_HEIGHTS := {
	"brick_1x1":       1.2,
	"brick_1x2":       1.2,
	"brick_2x2":       1.2,
	"brick_1x4":       1.2,
	"brick_2x4":       1.2,
	"plate_1x1":       0.48,
	"plate_1x2":       0.48,
	"plate_2x2":       0.48,
	"brick_corner":    1.2,
	"brick_slope_1x2": 1.2,
}

# Desk top-surface Y in world space  (desk node at y=0.8, half-depth 0.01)
const DESK_Y := 0.81

# Return the Y-centre for a brick of the given type resting on the desk surface.
static func floor_y(type: String) -> float:
	var h: float = BRICK_HEIGHTS.get(type, 1.2) * BRICK_SCALE
	return DESK_Y + h * 0.5 + 0.002   # 2 mm clearance to prevent tunnelling

# Snap a world position to the nearest XZ grid cell.
# Y is not snapped here — use floor_y() for surface placement.
static func snap(world_pos: Vector3) -> Vector3:
	var c: float = CELL_SIZE
	var x: float = round(world_pos.x / c) * c
	var z: float = round(world_pos.z / c) * c
	return Vector3(x, world_pos.y, z)
