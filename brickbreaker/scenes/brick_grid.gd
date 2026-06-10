extends Node2D

# Emitted when any brick is destroyed (for scoring/powerups in main.gd).
signal destroyed(points, pos, tier)

# Emitted when any brick breaks (for cascade spawning in this grid).
signal broken(pos: Vector2, tier: int)

# Emitted when all bricks in the level are gone.
signal cleared

const BRICK := preload("res://scenes/brick.tscn")
const MAX_LEVEL := 10

# Brick sprite 64x64, scaled 1.035 in brick.tscn.
const BRICK_W := 66.24
const BRICK_H := 66.24
const SPACING := 4.0
const COLS := 6
const TOP_MARGIN := 84.0

# Column-based level layouts. Each column has a starting tier (1–5).
# Bricks cascade down: red→orange→yellow→green→blue→gone.
const LEVEL_LAYOUTS: Array[Dictionary] = [
	{}, # placeholder for 0-index
	{"cols": [1, 1, 1, 1, 1, 1]}, # L1: 6 blue = 60
	{"cols": [2, 1, 1, 1, 1, 2]}, # L2: 2×40 + 4×10 = 120
	{"cols": [2, 2, 1, 1, 2, 2]}, # L3: 4×40 + 2×10 = 180
	{"cols": [3, 1, 2, 2, 1, 3]}, # L4: 2×90 + 2×40 + 2×10 = 280
	{"cols": [3, 2, 1, 1, 2, 3]}, # L5: 2×90 + 2×40 + 2×10 = 280
	{"cols": [3, 3, 2, 2, 3, 3]}, # L6: 4×90 + 2×40 = 440
	{"cols": [4, 1, 3, 3, 1, 4]}, # L7: 2×130 + 2×90 + 2×10 = 460
	{"cols": [4, 3, 2, 2, 3, 4]}, # L8: 2×130 + 2×90 + 2×40 = 520
	{"cols": [4, 4, 3, 3, 4, 4]}, # L9: 4×130 + 2×90 = 700
	{"cols": [5, 4, 3, 3, 4, 5]}, # L10: 2×170 + 2×90 + 2×130 = 790
]

var _live_count := 0

func build_level(level: int) -> void:
	_clear()
	var layout_level := clampi(level, 1, MAX_LEVEL)
	var layout: Dictionary = LEVEL_LAYOUTS[layout_level]
	var screen := get_viewport_rect().size
	var total_w := COLS * BRICK_W + (COLS - 1) * SPACING
	var start_x := (screen.x - total_w) * 0.5 + BRICK_W * 0.5
	_live_count = 0
	for c in COLS:
		var tier: int = layout.cols[c]
		for t in range(tier, 0, -1):
			_spawn_brick(tier, start_x + c * (BRICK_W + SPACING), TOP_MARGIN + (tier - t) * (BRICK_H + SPACING))

func _spawn_brick(tier: int, x: float, y: float) -> void:
	var brick := BRICK.instantiate()
	add_child(brick)
	brick.position = Vector2(x, y)
	brick.setup(tier)
	brick.destroyed.connect(_on_brick_destroyed)
	brick.broken.connect(_on_brick_broken)
	_live_count += 1

func _on_brick_destroyed(points: int, pos: Vector2, tier: int) -> void:
	_live_count -= 1
	destroyed.emit(points, pos, tier)
	if _live_count <= 0:
		cleared.emit()

func _on_brick_broken(pos: Vector2, tier: int) -> void:
	# Cascade: spawn a smaller brick below the destroyed one.
	if tier > 1:
		_live_count += 1
		_spawn_brick(tier - 1, pos.x, pos.y + BRICK_H + SPACING)

func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_live_count = 0
