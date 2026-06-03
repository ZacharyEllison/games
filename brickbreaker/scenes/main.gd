extends Node2D

enum State { IDLE, PLAYING, LEVEL_CLEAR, GAME_OVER }

const PADDLE_Y := 660.0
const BALL_OFFSET := Vector2(0, -26)
const BALL := preload("res://scenes/ball.tscn")
const POWERUP := preload("res://scenes/powerup.tscn")
# Drop chance keyed on brick strength tier (max_hits): tier 1 (green) is very
# rare, tougher higher-row bricks drop power-ups much more often.
const POWERUP_CHANCE_BY_TIER := {
	1: 0.033,
	2: 0.165,
	3: 0.33,
}

var state := State.IDLE
var level := 1
var score := 0
var lives := 3
var balls_in_play := 0
var base_ball_speed := 330.0
var held_ball: CharacterBody2D = null

@onready var paddle: CharacterBody2D = $Paddle
@onready var grid: Node2D = $BrickGrid
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	randomize()
	var screen := get_viewport_rect().size
	paddle.global_position = Vector2(screen.x * 0.5, PADDLE_Y)
	grid.brick_destroyed.connect(_on_brick_destroyed)
	grid.cleared.connect(_on_level_cleared)
	_new_game()

func _new_game() -> void:
	level = 1
	score = 0
	lives = 3
	hud.set_score(score)
	hud.set_lives(lives)
	hud.hide_message()
	_start_level()

func _start_level() -> void:
	_clear_balls()
	_clear_powerups()
	grid.build_level(level)
	base_ball_speed = (300.0 + (level - 1) * 35.0) * 1.1
	_spawn_held_ball()
	state = State.IDLE

func _make_ball(kind: int) -> CharacterBody2D:
	var ball: CharacterBody2D = BALL.instantiate()
	add_child(ball)
	ball.speed = base_ball_speed
	ball.set_kind(kind)
	ball.lost.connect(_on_ball_lost.bind(ball))
	return ball

func _spawn_held_ball() -> void:
	held_ball = _make_ball(0)
	held_ball.active = false

func _process(_delta: float) -> void:
	if state == State.IDLE and is_instance_valid(held_ball):
		held_ball.global_position = paddle.global_position + BALL_OFFSET
		if Input.is_action_just_pressed("press"):
			held_ball.launch(Vector2(randf_range(-0.35, 0.35), -1.0))
			balls_in_play = 1
			held_ball = null
			state = State.PLAYING
	elif state == State.GAME_OVER:
		if Input.is_action_just_pressed("press"):
			_new_game()

func spawn_extra_balls(pos: Vector2, count: int) -> void:
	if state != State.PLAYING:
		return
	for i in count:
		var ball := _make_ball(0)
		ball.global_position = pos
		var angle := randf_range(-0.9, 0.9)
		ball.launch(Vector2(sin(angle), -cos(angle)))
		balls_in_play += 1

func explode_at(pos: Vector2, radius: float) -> void:
	for brick in get_tree().get_nodes_in_group("bricks"):
		if is_instance_valid(brick) and brick.global_position.distance_to(pos) <= radius:
			brick.shatter()

func _on_ball_lost(ball: Node) -> void:
	if is_instance_valid(ball):
		ball.queue_free()
	balls_in_play -= 1
	if state != State.PLAYING:
		return
	if balls_in_play <= 0:
		balls_in_play = 0
		lives -= 1
		hud.set_lives(lives)
		if lives <= 0:
			state = State.GAME_OVER
			hud.show_message("GAME OVER")
		else:
			_clear_powerups()
			_spawn_held_ball()
			state = State.IDLE

func _on_brick_destroyed(points: int, pos: Vector2, tier: int) -> void:
	score += points
	hud.set_score(score)
	var chance: float = POWERUP_CHANCE_BY_TIER.get(tier, 0.03)
	if randf() < chance:
		_drop_powerup(pos)

func _drop_powerup(pos: Vector2) -> void:
	var powerup: Area2D = POWERUP.instantiate()
	add_child(powerup)
	powerup.global_position = pos
	powerup.set_kind(randi() % 3)
	powerup.collected.connect(_on_powerup_collected)

func _on_powerup_collected(kind: int) -> void:
	match kind:
		0: # MULTIBALL
			var positions: Array = []
			for ball in get_tree().get_nodes_in_group("balls"):
				positions.append(ball.global_position)
			for pos in positions:
				spawn_extra_balls(pos, 2)
		1: # SPLITTER
			for ball in get_tree().get_nodes_in_group("balls"):
				ball.set_kind(1)
		2: # EXPLODER
			for ball in get_tree().get_nodes_in_group("balls"):
				ball.set_kind(2)

func _on_level_cleared() -> void:
	if state != State.PLAYING:
		return
	state = State.LEVEL_CLEAR
	_clear_balls()
	_clear_powerups()
	hud.show_message("LEVEL %d" % (level + 1))
	await get_tree().create_timer(1.2).timeout
	hud.hide_message()
	level += 1
	_start_level()

func _clear_balls() -> void:
	held_ball = null
	for ball in get_tree().get_nodes_in_group("balls"):
		ball.queue_free()
	balls_in_play = 0

func _clear_powerups() -> void:
	for powerup in get_tree().get_nodes_in_group("powerups"):
		powerup.queue_free()
