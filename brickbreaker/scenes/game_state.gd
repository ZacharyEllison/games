extends Node2D

signal score_changed(value: int)
signal lives_changed(value: int)
signal state_changed(new_state: State)
signal ball_lost(ball: Node)
signal brick_destroyed(points: int, pos: Vector2, tier: int)
signal brick_hit(points: int, pos: Vector2, tier: int)
signal level_cleared
signal nice_catch(pos: Vector2)

enum State { IDLE, PLAYING, LEVEL_CLEAR, GAME_OVER, PAUSED, VICTORY }

var state := State.IDLE
var score := 0
var lives := 3
var balls_in_play := 0
var level := 1
var _lives_lost_this_level := 0
var max_unlocked_level := 1
var base_ball_speed := 330.0

func reset() -> void:
	score = 0
	lives = 3
	balls_in_play = 0
	level = 1
	max_unlocked_level = 1
	_lives_lost_this_level = 0
	base_ball_speed = 330.0
	state = State.IDLE
	score_changed.emit(0)
	lives_changed.emit(3)

func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

func lose_ball() -> void:
	balls_in_play -= 1
	if balls_in_play <= 0:
		balls_in_play = 0
		lives -= 1
		_lives_lost_this_level += 1
		lives_changed.emit(lives)
		if lives <= 0:
			state = State.GAME_OVER
			state_changed.emit(state)
		else:
			state = State.IDLE
			state_changed.emit(state)

func get_powerup_kind(tier: int) -> int:
	if tier == 1:
		var roll := randf()
		if roll < 0.35:
			return 3
		roll -= 0.35
		if roll < 0.217:
			return 0
		roll -= 0.217
		if roll < 0.217:
			return 1
		return 2
	return randi() % 4
