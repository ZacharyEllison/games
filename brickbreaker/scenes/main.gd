extends Node2D

enum State { IDLE, PLAYING, LEVEL_CLEAR, GAME_OVER, PAUSED, VICTORY }

const MAX_LEVEL := 10

const BALL_OFFSET := Vector2(0, -26)
const BALL := preload("res://scenes/ball.tscn")
const POWERUP := preload("res://scenes/powerup.tscn")
const POWERUP_CHANCE_BY_TIER := {
	1: 0.033,
	2: 0.165,
	3: 0.33,
	4: 0.40,
	5: 0.45,
}
# Tier 1 (blue): ONE_UP weighted higher; tiers 2–5 equal across 4 kinds.
const ONE_UP_WEIGHT_TIER1 := 0.35
const OTHER_WEIGHT_TIER1 := 0.217
const WEIGHT_TIER_OTHER := 0.25

var state := State.IDLE
var level := 1
var score := 0
var lives := 3
var balls_in_play := 0
var base_ball_speed := 330.0
var max_unlocked_level := 1
var held_ball: CharacterBody2D = null

var _lives_lost_this_level := 0
var _level_points := 0
var _paddle_y := 612.0

@onready var paddle: CharacterBody2D = $Paddle
@onready var grid: Node2D = $BrickGrid
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	randomize()
	var screen := get_viewport_rect().size
	_paddle_y = screen.y * 0.85
	paddle.global_position = Vector2(screen.x * 0.5, _paddle_y)
	grid.brick_scored.connect(_on_brick_scored)
	grid.brick_destroyed.connect(_on_brick_destroyed)
	grid.cleared.connect(_on_level_cleared)
	hud.pause_requested.connect(_on_pause_requested)
	hud.resume_requested.connect(_on_resume_requested)
	hud.restart_requested.connect(_on_restart_from_pause)
	hud.level_selected.connect(_on_level_selected)
	max_unlocked_level = SaveManager.max_unlocked_level
	hud.set_high_score(SaveManager.high_score)
	_new_game()

func _paddle_y_for_screen() -> float:
	return get_viewport_rect().size.y * 0.85

func _new_game() -> void:
	get_tree().paused = false
	level = 1
	score = 0
	lives = 3
	_lives_lost_this_level = 0
	_level_points = 0
	hud.set_score(score)
	hud.set_lives(lives)
	hud.hide_game_over()
	hud.hide_perfect()
	hud.hide_victory()
	hud.set_pause_menu_visible(false, max_unlocked_level)
	_start_level()

func _start_level() -> void:
	_clear_balls()
	_clear_powerups()
	_paddle_y = _paddle_y_for_screen()
	paddle.global_position = Vector2(get_viewport_rect().size.x * 0.5, _paddle_y)
	grid.build_level(level)
	base_ball_speed = (300.0 + (level - 1) * 35.0) * 1.1
	_lives_lost_this_level = 0
	_level_points = 0
	_spawn_held_ball()
	state = State.IDLE

func _make_ball(kind: int, speed_scale: float = 1.0) -> CharacterBody2D:
	var ball: CharacterBody2D = BALL.instantiate()
	add_child(ball)
	ball.speed = base_ball_speed * speed_scale
	ball.set_kind(kind)
	ball.lost.connect(_on_ball_lost.bind(ball))
	ball.nice_catch.connect(_on_nice_catch)
	return ball

func _spawn_held_ball() -> void:
	held_ball = _make_ball(0)
	held_ball.active = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING or state == State.IDLE:
			_pause_game()
		elif state == State.PAUSED:
			_on_resume_requested()

func _process(_delta: float) -> void:
	if state == State.PAUSED:
		return
	if state == State.IDLE and is_instance_valid(held_ball):
		held_ball.global_position = paddle.global_position + BALL_OFFSET
		if Input.is_action_just_pressed("press"):
			AudioManager.unlock()
			held_ball.launch(Vector2(randf_range(-0.35, 0.35), -1.0))
			balls_in_play = 1
			held_ball = null
			state = State.PLAYING
	elif state == State.LEVEL_CLEAR:
		if Input.is_action_just_pressed("press"):
			AudioManager.unlock()
			_advance_after_perfect()

func spawn_extra_balls(pos: Vector2, count: int, speed_scale: float = 1.0) -> void:
	if state != State.PLAYING:
		return
	for i in count:
		var ball := _make_ball(0, speed_scale)
		ball.global_position = pos
		var angle := randf_range(-0.9, 0.9)
		ball.launch(Vector2(sin(angle), -cos(angle)))
		balls_in_play += 1

func explode_at(pos: Vector2, radius: float) -> void:
	for brick in get_tree().get_nodes_in_group("bricks"):
		if is_instance_valid(brick) and brick.global_position.distance_to(pos) <= radius:
			brick.shatter()

func _on_nice_catch(pos: Vector2) -> void:
	hud.show_slam_text("NICE CATCH!", pos)

func _on_ball_lost(ball: Node) -> void:
	if is_instance_valid(ball):
		ball.queue_free()
	balls_in_play -= 1
	if state != State.PLAYING:
		return
	if balls_in_play <= 0:
		balls_in_play = 0
		lives -= 1
		_lives_lost_this_level += 1
		hud.set_lives(lives)
		if lives <= 0:
			state = State.GAME_OVER
			var new_best := SaveManager.record_game_end(score, false)
			hud.set_high_score(SaveManager.high_score)
			hud.show_game_over(score, SaveManager.high_score, new_best, SaveManager.games_played, SaveManager.games_won)
		else:
			_clear_powerups()
			_spawn_held_ball()
			state = State.IDLE

func _on_brick_scored(points: int, _pos: Vector2, _tier: int) -> void:
	score += points
	_level_points += points
	hud.set_score(score)

func _on_brick_destroyed(pos: Vector2, tier: int) -> void:
	var chance: float = POWERUP_CHANCE_BY_TIER.get(tier, 0.03)
	if randf() < chance:
		_drop_powerup(pos, tier)

func _pick_powerup_kind(tier: int) -> int:
	if tier == 1:
		var roll := randf()
		if roll < ONE_UP_WEIGHT_TIER1:
			return 3
		roll -= ONE_UP_WEIGHT_TIER1
		if roll < OTHER_WEIGHT_TIER1:
			return 0
		roll -= OTHER_WEIGHT_TIER1
		if roll < OTHER_WEIGHT_TIER1:
			return 1
		return 2
	return randi() % 4

func _drop_powerup(pos: Vector2, tier: int) -> void:
	var powerup: Area2D = POWERUP.instantiate()
	add_child(powerup)
	powerup.global_position = pos
	powerup.set_kind(_pick_powerup_kind(tier))
	powerup.collected.connect(_on_powerup_collected)

func _on_powerup_collected(kind: int) -> void:
	match kind:
		0: # MULTIBALL
			var positions: Array = []
			for ball in get_tree().get_nodes_in_group("balls"):
				positions.append(ball.global_position)
			for pos in positions:
				spawn_extra_balls(pos, 2, 0.85)
		1: # SPLITTER
			for ball in get_tree().get_nodes_in_group("balls"):
				ball.set_kind(1)
		2: # EXPLODER
			for ball in get_tree().get_nodes_in_group("balls"):
				ball.set_kind(2)
		3: # ONE_UP
			lives += 1
			hud.set_lives(lives)

func _on_level_cleared() -> void:
	if state != State.PLAYING:
		return
	state = State.LEVEL_CLEAR
	_clear_balls()
	_clear_powerups()
	var was_perfect := _lives_lost_this_level == 0 and _level_points > 0
	if was_perfect:
		score += _level_points
		hud.set_score(score)
		hud.show_perfect()
		hud.slam_score()
	max_unlocked_level = mini(maxi(max_unlocked_level, level + 1), MAX_LEVEL)
	SaveManager.set_max_unlocked_level(max_unlocked_level)
	if level >= MAX_LEVEL:
		state = State.VICTORY
		hud.hide_perfect()
		var new_best := SaveManager.record_game_end(score, true)
		hud.set_high_score(SaveManager.high_score)
		hud.show_victory(score, SaveManager.high_score, new_best, SaveManager.games_played, SaveManager.games_won)
		return
	hud.show_level_transition("LEVEL %d" % (level + 1))
	await get_tree().create_timer(1.4).timeout
	level += 1
	_start_level()

func _advance_after_perfect() -> void:
	if state != State.LEVEL_CLEAR:
		return
	hud.hide_perfect()
	level += 1
	_start_level()

func _pause_game() -> void:
	if state != State.PLAYING and state != State.IDLE:
		return
	state = State.PAUSED
	get_tree().paused = true
	hud.set_pause_menu_visible(true, max_unlocked_level)

func _on_pause_requested() -> void:
	_pause_game()

func _on_resume_requested() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	hud.set_pause_menu_visible(false, max_unlocked_level)
	if is_instance_valid(held_ball):
		state = State.IDLE
	else:
		state = State.PLAYING

func _on_restart_from_pause() -> void:
	get_tree().paused = false
	hud.set_pause_menu_visible(false, max_unlocked_level)
	_new_game()

func _on_level_selected(selected_level: int) -> void:
	get_tree().paused = false
	hud.set_pause_menu_visible(false, max_unlocked_level)
	level = selected_level
	_lives_lost_this_level = 0
	_level_points = 0
	hud.hide_game_over()
	hud.hide_perfect()
	hud.hide_victory()
	_start_level()

func _clear_balls() -> void:
	held_ball = null
	for ball in get_tree().get_nodes_in_group("balls"):
		ball.queue_free()
	balls_in_play = 0

func _clear_powerups() -> void:
	for powerup in get_tree().get_nodes_in_group("powerups"):
		powerup.queue_free()
