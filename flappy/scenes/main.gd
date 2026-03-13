extends Node2D

@onready var sky: ColorRect = $Sky
@onready var player: Area2D = $player

var pipe_scene := preload("res://scenes/pipe.tscn")
var pipes := []
var pipe_timer := 0.0
var pipe_interval := 1.5
var pipe_width := 80
var pipe_speed := 200
var pipe_gap := 190
var pipe_min_height := 90

func _ready() -> void:
	randomize()
	_resize_sky()
	get_viewport().size_changed.connect(_resize_sky)

func _resize_sky() -> void:
	sky.position = Vector2.ZERO
	sky.size = get_viewport_rect().size

func _process(delta: float) -> void:
	pipe_timer += delta
	if pipe_timer >= pipe_interval:
		spawn_pipe_pair()
		pipe_timer = 0.0

	var active_pipes := []
	for pipe in pipes:
		if not is_instance_valid(pipe):
			continue
		if pipe.position.x + pipe.width < 0:
			continue
		if _player_hits_pipe(pipe):
			reset_game()
			return
		active_pipes.append(pipe)
	pipes = active_pipes

func _player_hits_pipe(pipe) -> bool:
	var pipe_left = pipe.global_position.x
	var pipe_right = pipe_left + pipe.width
	if player.global_position.x < pipe_left or player.global_position.x > pipe_right:
		return false

	if pipe.spawn_top:
		return player.global_position.y < pipe.global_position.y + pipe.height

	return player.global_position.y > pipe.global_position.y

func _spawn_pipe(x_position: float, y_position: float, pipe_height: int, is_top_pipe: bool) -> void:
	var pipe = pipe_scene.instantiate()
	pipe.width = pipe_width
	pipe.height = pipe_height
	pipe.speed = pipe_speed
	pipe.spawn_top = is_top_pipe
	pipe.position = Vector2(x_position, y_position)
	add_child(pipe)
	pipes.append(pipe)

func spawn_pipe_pair() -> void:
	var viewport_size = get_viewport_rect().size
	var available_height = int(viewport_size.y) - pipe_gap
	if available_height <= pipe_min_height * 2:
		return

	var top_height = randi_range(pipe_min_height, available_height - pipe_min_height)
	var bottom_height = available_height - top_height
	var x_position = viewport_size.x

	_spawn_pipe(x_position, 0.0, top_height, true)
	_spawn_pipe(x_position, float(top_height + pipe_gap), bottom_height, false)

func reset_game() -> void:
	pipe_timer = 0.0
	player._reset_to_center()
	for pipe in pipes:
		if is_instance_valid(pipe):
			pipe.queue_free()
	pipes.clear()
