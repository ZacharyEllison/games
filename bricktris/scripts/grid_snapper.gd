class_name GridSnapper
extends RefCounted

# UPDATE after measuring the imported GLB: open bevel-hq-brick-1x1.glb in the
# Godot editor and read the MeshInstance3D AABB x-size. Set CELL_SIZE to that
# value. If the mesh is too large (>0.1 m), also set import scale in the GLB
# import settings: Scale = 0.032 / measured_size (physical LEGO stud = 3.2 cm).
const CELL_SIZE := 1.0

# Brick footprint in stud units [x, y, z].
# y-component for plates is 0.4 (plates are 1/3 the height of bricks).
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

const DESK_TOP := 0.85  # desk is at y=0.8, top surface at y=0.85

# Snap a world position to the nearest grid cell centre.
# dims: the brick's stud dimensions from BRICK_DEFS.
static func snap(world_pos: Vector3, dims: Vector3) -> Vector3:
	var c: float = CELL_SIZE
	var x: float = round(world_pos.x / c) * c + ((dims.x / 2.0) - 0.5) * c
	var y: float = max(DESK_TOP, round(world_pos.y / c) * c)
	var z: float = round(world_pos.z / c) * c + ((dims.z / 2.0) - 0.5) * c
	return Vector3(x, y, z)
