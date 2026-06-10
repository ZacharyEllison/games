extends Node2D

const MAX_LEVEL := 10

signal level_changed(level: int)
signal level_cleared
signal victory(score: int)
signal level_start(level: int)

var current_level := 1
var max_unlocked_level := 1
var _paddle: CharacterBody2D

func start_level(level: int, grid: Node2D, paddle: CharacterBody2D, screen: Vector2) -> void:
	_paddle = paddle
	current_level = level
	paddle.global_position = Vector2(screen.x * 0.5, screen.y * 0.85)
	grid.build_level(level)
	level_changed.emit(level)
	level_start.emit(level)

func on_level_cleared(grid: Node2D, hud: CanvasLayer) -> void:
	max_unlocked_level = min(max(max_unlocked_level, current_level + 1), MAX_LEVEL)
	if current_level >= MAX_LEVEL:
		return
	hud.show_message("LEVEL %d" % (current_level + 1))
	await get_tree().create_timer(1.2).timeout
	hud.hide_message()
	current_level += 1
	start_level(current_level, grid, _paddle, get_viewport_rect().size)

func select_level(level: int, grid: Node2D, paddle: CharacterBody2D, screen: Vector2) -> void:
	current_level = level
	start_level(level, grid, paddle, screen)
