class_name GridSnapper
extends RefCounted

# Kenney bricks are ~1 Godot unit per stud at native scale.
# We scale all bricks by BRICK_SCALE so 1 stud = 0.04m (4cm) in VR.
const BRICK_SCALE := 0.04
const CELL_SIZE := 0.04  # world-space size of one stud after scaling

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

# Desk surface y-position (top of the baseplate)
const DESK_Y := 0.82

# Snap a world position to the nearest grid cell on the baseplate.
static func snap(world_pos: Vector3, dims: Vector3) -> Vector3:
	var c: float = CELL_SIZE
	var x: float = round(world_pos.x / c) * c
	var y: float = max(DESK_Y, round(world_pos.y / c) * c)
	var z: float = round(world_pos.z / c) * c
	return Vector3(x, y, z)
