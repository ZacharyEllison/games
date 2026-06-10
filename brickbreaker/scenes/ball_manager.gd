extends Node2D

const BALL := preload("res://scenes/ball.tscn")
const BALL_OFFSET := Vector2(0, -26)

signal ball_spawned(ball: CharacterBody2D)
signal ball_lost(ball: Node)
signal nice_catch(pos: Vector2)

var _balls: Array[CharacterBody2D] = []
var held_ball: CharacterBody2D = null
var base_ball_speed := 330.0

func spawn_ball(kind: int, speed_scale: float = 1.0, pos: Vector2 = Vector2.ZERO, launched: bool = false) -> CharacterBody2D:
	var ball := BALL.instantiate()
	add_child(ball)
	_balls.append(ball)
	ball.speed = base_ball_speed * speed_scale
	ball.set_kind(kind)
	ball.lost.connect(func(): ball_lost.emit(ball))
	ball.nice_catch.connect(func(p): nice_catch.emit(p))
	if launched:
		var angle := randf_range(-0.9, 0.9)
		ball.launch(Vector2(sin(angle), -cos(angle)))
	else:
		ball.active = false
	ball_spawned.emit(ball)
	return ball

func spawn_held_ball() -> void:
	held_ball = spawn_ball(0, 1.0, Vector2.ZERO, false)

func spawn_extra_balls(pos: Vector2, count: int, speed_scale: float = 1.0) -> void:
	for i in count:
		spawn_ball(0, speed_scale, pos, true)

func clear_all() -> void:
	held_ball = null
	for ball in _balls:
		ball.queue_free()
	_balls.clear()

func launch_held() -> void:
	if not is_instance_valid(held_ball):
		return
	held_ball.launch(Vector2(randf_range(-0.35, 0.35), -1.0))
	held_ball = null
