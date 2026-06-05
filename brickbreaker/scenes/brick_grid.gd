extends Node2D

signal brick_destroyed(points, pos, tier)
signal cleared

const BRICK := preload("res://scenes/brick.tscn")
const MAX_LEVEL := 10

# Brick sprite 64x64, scaled 1.035 in brick.tscn.
const BRICK_W := 66.24
const BRICK_H := 66.24
const SPACING := 4.0
const COLS := 6
const TOP_MARGIN := 84.0

const ORANGE_MODULATE := Color(1.0, 0.58, 0.12)

enum Roygb { BLUE, GREEN, YELLOW, ORANGE, RED }

# Row colors top to bottom (row 0 = top of screen).
const LEVEL_LAYOUTS: Dictionary = {
	1: [Roygb.BLUE, Roygb.BLUE],
	2: [Roygb.GREEN, Roygb.BLUE, Roygb.BLUE],
	3: [Roygb.YELLOW, Roygb.GREEN, Roygb.BLUE, Roygb.BLUE],
	4: [Roygb.YELLOW, Roygb.GREEN, Roygb.GREEN, Roygb.BLUE],
	5: [Roygb.YELLOW, Roygb.YELLOW, Roygb.GREEN, Roygb.GREEN, Roygb.BLUE],
	6: [Roygb.ORANGE, Roygb.YELLOW, Roygb.GREEN, Roygb.GREEN, Roygb.BLUE],
	7: [Roygb.ORANGE, Roygb.YELLOW, Roygb.YELLOW, Roygb.GREEN, Roygb.BLUE],
	8: [Roygb.ORANGE, Roygb.ORANGE, Roygb.YELLOW, Roygb.GREEN, Roygb.BLUE],
	9: [Roygb.RED, Roygb.ORANGE, Roygb.YELLOW, Roygb.GREEN, Roygb.BLUE],
	10: [Roygb.RED, Roygb.ORANGE, Roygb.YELLOW, Roygb.GREEN, Roygb.GREEN],
}

# Damage progression per tier (hits taken indexes into this list).
const TIER_PROGRESSION: Dictionary = {
	1: [Roygb.BLUE],
	2: [Roygb.GREEN, Roygb.BLUE],
	3: [Roygb.YELLOW, Roygb.GREEN, Roygb.BLUE],
	4: [Roygb.ORANGE, Roygb.YELLOW, Roygb.GREEN, Roygb.BLUE],
	5: [Roygb.RED, Roygb.ORANGE, Roygb.YELLOW, Roygb.GREEN, Roygb.BLUE],
}

var _tex_blue: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Blue/brick_high_2.png")
var _tex_green: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Green/brick_high_2.png")
var _tex_yellow: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Yellow/brick_high_2.png")
var _tex_red: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Red/brick_high_2.png")

var _live_count := 0

func build_level(level: int) -> void:
	_clear()
	var layout_level := clampi(level, 1, MAX_LEVEL)
	var layout: Array = LEVEL_LAYOUTS[layout_level]
	var rows := layout.size()
	var screen := get_viewport_rect().size
	var total_w := COLS * BRICK_W + (COLS - 1) * SPACING
	var start_x := (screen.x - total_w) * 0.5 + BRICK_W * 0.5
	_live_count = 0
	for r in rows:
		var color: Roygb = layout[r]
		var tier := _tier_for_color(color)
		var stage_data := _stages_for_tier(tier)
		for c in COLS:
			var brick := BRICK.instantiate()
			add_child(brick)
			brick.position = Vector2(
				start_x + c * (BRICK_W + SPACING),
				TOP_MARGIN + r * (BRICK_H + SPACING)
			)
			brick.setup(tier, stage_data)
			brick.destroyed.connect(_on_brick_destroyed)
			_live_count += 1

func _tier_for_color(color: Roygb) -> int:
	match color:
		Roygb.GREEN:
			return 2
		Roygb.YELLOW:
			return 3
		Roygb.ORANGE:
			return 4
		Roygb.RED:
			return 5
		_:
			return 1

func _stages_for_tier(tier: int) -> Array:
	var colors: Array = TIER_PROGRESSION.get(tier, TIER_PROGRESSION[1])
	var stages: Array = []
	for color in colors:
		stages.append(_stage_for_color(color))
	return stages

func _stage_for_color(color: Roygb) -> Dictionary:
	match color:
		Roygb.GREEN:
			return {"texture": _tex_green, "modulate": Color.WHITE}
		Roygb.YELLOW:
			return {"texture": _tex_yellow, "modulate": Color.WHITE}
		Roygb.ORANGE:
			return {"texture": _tex_yellow, "modulate": ORANGE_MODULATE}
		Roygb.RED:
			return {"texture": _tex_red, "modulate": Color.WHITE}
		_:
			return {"texture": _tex_blue, "modulate": Color.WHITE}

func _on_brick_destroyed(points: int, pos: Vector2, tier: int) -> void:
	_live_count -= 1
	brick_destroyed.emit(points, pos, tier)
	if _live_count <= 0:
		cleared.emit()

func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_live_count = 0
