extends Node2D

signal brick_destroyed(points, pos, tier)
signal cleared

const BRICK := preload("res://scenes/brick.tscn")

# Brick sprite is 64x64 (square), scaled 1.15 in brick.tscn -> effective footprint below.
const BRICK_W := 73.6
const BRICK_H := 73.6
const SPACING := 4.0
const COLS := 6
const TOP_MARGIN := 84.0

var _tex_green: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Green/brick_high_2.png")
var _tex_blue: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Blue/brick_high_2.png")
var _tex_yellow: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Yellow/brick_high_2.png")
var _tex_red: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Red/brick_high_2.png")

var _live_count := 0

func build_level(level: int) -> void:
	_clear()
	var rows := clampi(2 + level, 2, 5)
	var screen := get_viewport_rect().size
	var total_w := COLS * BRICK_W + (COLS - 1) * SPACING
	var start_x := (screen.x - total_w) * 0.5 + BRICK_W * 0.5
	_live_count = 0
	for r in rows:
		for c in COLS:
			var hits := _strength_for_row(r, rows)
			var brick := BRICK.instantiate()
			add_child(brick)
			brick.position = Vector2(
				start_x + c * (BRICK_W + SPACING),
				TOP_MARGIN + r * (BRICK_H + SPACING)
			)
			brick.setup(hits, _textures_for(hits))
			brick.destroyed.connect(_on_brick_destroyed)
			_live_count += 1

func _strength_for_row(row: int, rows: int) -> int:
	# Top rows are tougher.
	var depth := rows - row
	return clampi(int(ceil(depth / 2.0)), 1, 3)

func _textures_for(hits: int) -> Array:
	match hits:
		3:
			return [_tex_red, _tex_yellow, _tex_green]
		2:
			return [_tex_blue, _tex_green]
		_:
			return [_tex_green]

func _on_brick_destroyed(points: int, pos: Vector2, tier: int) -> void:
	_live_count -= 1
	brick_destroyed.emit(points, pos, tier)
	if _live_count <= 0:
		cleared.emit()

func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_live_count = 0
