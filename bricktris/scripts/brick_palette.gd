class_name BrickPalette
extends Node3D

const BRICK_SCENES := {
	"brick_1x1":       preload("res://scenes/brick_1x1.tscn"),
	"brick_1x2":       preload("res://scenes/brick_1x2.tscn"),
	"brick_2x2":       preload("res://scenes/brick_2x2.tscn"),
	"brick_1x4":       preload("res://scenes/brick_1x4.tscn"),
	"brick_2x4":       preload("res://scenes/brick_2x4.tscn"),
	"plate_1x1":       preload("res://scenes/plate_1x1.tscn"),
	"plate_1x2":       preload("res://scenes/plate_1x2.tscn"),
	"plate_2x2":       preload("res://scenes/plate_2x2.tscn"),
	"brick_corner":    preload("res://scenes/brick_corner.tscn"),
	"brick_slope_1x2": preload("res://scenes/brick_slope_1x2.tscn"),
}

# 2 rows x 5 cols — row 0 = bricks, row 1 = plates/specials
const LAYOUT: Array = [
	["brick_1x1", "brick_1x2", "brick_2x2", "brick_1x4", "brick_2x4"],
	["plate_1x1", "plate_1x2", "plate_2x2", "brick_corner", "brick_slope_1x2"],
]

const SLOT_SPACING := 0.18  # metres between palette slots
const GRAB_RADIUS := 0.12   # hand must be within this distance to grab

var _slots: Array = []  # Array of {type, area, brick}
var _highlighted_type := ""

func _ready() -> void:
	_build_palette()

func _build_palette() -> void:
	var cols := LAYOUT[0].size()
	var rows := LAYOUT.size()
	for row in rows:
		for col in cols:
			var type: String = LAYOUT[row][col]
			var offset := Vector3(
				(col - (cols - 1) * 0.5) * SLOT_SPACING,
				-row * SLOT_SPACING,
				0.0
			)
			_add_slot(type, offset)

func _add_slot(type: String, offset: Vector3) -> void:
	var container := Node3D.new()
	container.position = offset
	add_child(container)

	# Display brick — frozen, no physics
	var brick: Brick = (BRICK_SCENES[type] as PackedScene).instantiate()
	brick.freeze = true
	brick.collision_layer = 0
	brick.collision_mask = 0
	# Scale down so bricks fit nicely in the palette (1x1 bricks are ~1m in-engine)
	brick.scale = Vector3.ONE * 0.12
	container.add_child(brick)

	# Grab detection area
	var area := Area3D.new()
	var cshape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = GRAB_RADIUS
	cshape.shape = sphere
	area.add_child(cshape)
	container.add_child(area)

	_slots.append({ "type": type, "area": area, "brick": brick, "container": container })

# Returns the type string of the nearest palette slot within GRAB_RADIUS, or ""
func get_nearest_type(hand_world_pos: Vector3) -> String:
	var best_dist := INF
	var best_type := ""
	for slot in _slots:
		var d: float = (slot["area"] as Area3D).global_position.distance_to(hand_world_pos)
		if d < GRAB_RADIUS and d < best_dist:
			best_dist = d
			best_type = slot["type"]
	return best_type

# Highlight the slot nearest to the hand (called every frame while no brick held)
func update_highlight(hand_world_pos: Vector3) -> void:
	var nearest := get_nearest_type(hand_world_pos)
	if nearest == _highlighted_type:
		return
	# Restore old highlight
	for slot in _slots:
		if slot["type"] == _highlighted_type:
			(slot["brick"] as Brick).set_ghost(false)
	# Apply new highlight
	_highlighted_type = nearest
	for slot in _slots:
		if slot["type"] == nearest:
			(slot["brick"] as Brick).set_ghost(true)  # blue tint = hover highlight
