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

# Two rows, spaced for the widest bricks (2x4 ~= 0.32 m).
const LAYOUT: Array = [
	["brick_1x1", "brick_1x2", "brick_2x2", "brick_1x4", "brick_2x4"],
	["plate_1x1", "plate_1x2", "plate_2x2", "brick_corner", "brick_slope_1x2"],
]

const COL_SPACING := 0.52
const ROW_SPACING := 0.42
const GRAB_RADIUS := 0.18

var _slots: Array = []
var _highlighted_type := ""

func _ready() -> void:
	_build_palette()

func _build_palette() -> void:
	var cols: int = LAYOUT[0].size()
	var rows: int = LAYOUT.size()
	for row in rows:
		for col in cols:
			var type: String = LAYOUT[row][col]
			var offset := Vector3(
				(col - (cols - 1) * 0.5) * COL_SPACING,
				-row * ROW_SPACING,
				0.0
			)
			_add_slot(type, offset)

func _add_slot(type: String, offset: Vector3) -> void:
	var container := Node3D.new()
	container.position = offset
	add_child(container)

	var brick: Brick = (BRICK_SCENES[type] as PackedScene).instantiate()
	brick.freeze = true
	brick.collision_layer = 0
	brick.collision_mask = 0
	container.add_child(brick)

	_slots.append({ "type": type, "brick": brick, "container": container })

func query_nearest(hand_world_pos: Vector3) -> Dictionary:
	var best_dist := INF
	var best_type := ""
	for slot in _slots:
		var slot_pos: Vector3 = (slot["container"] as Node3D).global_position
		var d: float = slot_pos.distance_to(hand_world_pos)
		if d < GRAB_RADIUS and d < best_dist:
			best_dist = d
			best_type = slot["type"]
	if best_type.is_empty():
		return { "type": "", "distance": INF }
	return { "type": best_type, "distance": best_dist }

func get_nearest_type(hand_world_pos: Vector3) -> String:
	return query_nearest(hand_world_pos)["type"]

func update_highlight(hand_world_pos: Vector3) -> void:
	var nearest := get_nearest_type(hand_world_pos)
	if nearest == _highlighted_type:
		return
	for slot in _slots:
		if slot["type"] == _highlighted_type:
			(slot["brick"] as Brick).set_highlighted(false)
	_highlighted_type = nearest
	for slot in _slots:
		if slot["type"] == nearest:
			(slot["brick"] as Brick).set_highlighted(true)
