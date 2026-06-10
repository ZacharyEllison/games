extends Node2D

enum State { IDLE, PLAYING, LEVEL_CLEAR, GAME_OVER, PAUSED, VICTORY }

@onready var ball_manager: Node2D = $BallManager
@onready var powerup_manager: Node2D = $PowerupManager
@onready var level_manager: Node2D = $LevelManager

@onready var paddle: CharacterBody2D = $Paddle
@onready var grid: Node2D = $BrickGrid
@onready var hud: CanvasLayer = $HUD

var state := State.IDLE
var score := 0
var lives := 3
var balls_in_play := 0
var _lives_lost_this_level := 0

func _ready() -> void:
	randomize()
	_wire_signals()
	_new_game()

func _wire_signals() -> void:
	ball_manager.ball_lost.connect(_on_ball_lost_signal)
	ball_manager.nice_catch.connect(func(p): hud.show_slam_text("NICE CATCH!", p))
	powerup_manager.on_collected.connect(_on_powerup_collected)
	grid.cleared.connect(_on_level_cleared)
	hud.pause_requested.connect(_on_pause_requested)
	hud.resume_requested.connect(_on_resume_requested)
	hud.restart_requested.connect(_on_restart_requested)
	hud.level_selected.connect(_on_level_selected)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()

func _new_game() -> void:
	score = 0
	lives = 3
	balls_in_play = 0
	_lives_lost_this_level = 0
	state = State.IDLE
	hud.set_score(0)
	hud.set_lives(3)
	hud.hide_message()
	hud.hide_game_over()
	hud.hide_victory()
	hud.set_pause_menu_visible(false, 1)
	_start_level()

func _start_level() -> void:
	ball_manager.clear_all()
	powerup_manager.clear_all()
	paddle.global_position = Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y * 0.85)
	level_manager.start_level(1, grid, paddle, get_viewport_rect().size)
	ball_manager.spawn_held_ball()
	state = State.IDLE
	hud.show_tap_prompt()

func _process(_delta: float) -> void:
	if state == State.PLAYING or state == State.IDLE:
		if is_instance_valid(ball_manager.held_ball):
			ball_manager.held_ball.global_position = paddle.global_position + Vector2(0, -26)
			if Input.is_action_just_pressed("press") and state == State.IDLE:
				AudioManager.unlock()
				ball_manager.launch_held()
				state = State.PLAYING
				hud.hide_tap_prompt()
	elif state == State.GAME_OVER or state == State.VICTORY:
		if Input.is_action_just_pressed("press"):
			_new_game()

func _toggle_pause() -> void:
	if get_tree().paused:
		_on_resume_requested()
	elif state == State.PLAYING or state == State.IDLE:
		_on_pause_requested()

func _on_pause_requested() -> void:
	get_tree().paused = true
	hud.set_pause_menu_visible(true, level_manager.max_unlocked_level)

func _on_resume_requested() -> void:
	get_tree().paused = false
	hud.set_pause_menu_visible(false, level_manager.max_unlocked_level)
	if is_instance_valid(ball_manager.held_ball):
		state = State.IDLE
		hud.show_tap_prompt()
	else:
		state = State.PLAYING

func _on_restart_requested() -> void:
	get_tree().paused = false
	hud.set_pause_menu_visible(false, level_manager.max_unlocked_level)
	_new_game()

func _on_level_selected(level: int) -> void:
	get_tree().paused = false
	hud.set_pause_menu_visible(false, level_manager.max_unlocked_level)
	level_manager.select_level(level, grid, paddle, get_viewport_rect().size)

func _on_ball_lost_signal(ball: Node) -> void:
	if is_instance_valid(ball):
		ball.queue_free()
	balls_in_play -= 1
	if balls_in_play <= 0:
		balls_in_play = 0
		lives -= 1
		_lives_lost_this_level += 1
		hud.set_lives(lives)
		if lives <= 0:
			state = State.GAME_OVER
		else:
			state = State.IDLE

func _on_powerup_collected(kind: int, pos: Vector2) -> void:
	match kind:
		0:  # MULTIBALL
			ball_manager.spawn_extra_balls(pos, 2, 0.85)
		1:  # SPLITTER
			for ball in get_tree().get_nodes_in_group("balls"):
				ball.set_kind(1)
		2:  # EXPLODER
			for brick in get_tree().get_nodes_in_group("bricks"):
				if is_instance_valid(brick) and brick.global_position.distance_to(pos) <= 95.0:
					brick.shatter()
		3:  # ONE_UP
			lives += 1
			hud.set_lives(lives)

func _on_level_cleared() -> void:
	state = State.LEVEL_CLEAR
	hud.hide_tap_prompt()
	ball_manager.clear_all()
	powerup_manager.clear_all()
	if _lives_lost_this_level == 0 and level_manager.current_level == 1:
		hud.show_perfect()
	level_manager.on_level_cleared(grid, hud)
