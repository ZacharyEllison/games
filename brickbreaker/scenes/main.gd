extends Node2D

@onready var game_state: Node2D = $GameState
@onready var ball_manager: Node2D = $BallManager
@onready var powerup_manager: Node2D = $PowerupManager
@onready var level_manager: Node2D = $LevelManager
@onready var pause_manager: Node2D = $PauseManager
@onready var input_manager: Node2D = $InputManager

@onready var paddle: CharacterBody2D = $Paddle
@onready var grid: Node2D = $BrickGrid
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	randomize()
	_wire_signals()
	_new_game()

func _wire_signals() -> void:
	# GameState wiring
	game_state.score_changed.connect(hud.set_score)
	game_state.lives_changed.connect(hud.set_lives)
	game_state.ball_lost.connect(_on_ball_lost)

	# BallManager wiring
	ball_manager.ball_spawned.connect(_on_ball_spawned)
	ball_manager.ball_lost.connect(game_state.lose_ball)
	ball_manager.nice_catch.connect(func(p): hud.show_slam_text("NICE CATCH!", p))

	# PowerupManager wiring
	powerup_manager.on_collected.connect(_on_powerup_collected)

	# LevelManager wiring
	grid.cleared.connect(_on_level_cleared)

	# PauseManager wiring
	pause_manager.pause_requested.connect(_on_pause_requested)
	pause_manager.resume_requested.connect(_on_resume_requested)
	pause_manager.restart_requested.connect(_on_restart_requested)
	pause_manager.level_selected.connect(_on_level_selected)

	# InputManager wiring
	input_manager.pause_toggle.connect(_on_pause_toggle)
	input_manager.launch_held_ball.connect(_on_launch_held)
	input_manager.restart_game.connect(_new_game)

func _new_game() -> void:
	game_state.reset()
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
	game_state.state = 0  # IDLE
	hud.show_tap_prompt()

func _process(_delta: float) -> void:
	if game_state.state == 1 or game_state.state == 0:  # PLAYING or IDLE
		if is_instance_valid(ball_manager.held_ball):
			ball_manager.held_ball.global_position = paddle.global_position + Vector2(0, -26)
			if Input.is_action_just_pressed("press") and game_state.state == 0:
				AudioManager.unlock()
				_on_launch_held()
	elif game_state.state == 3 or game_state.state == 5:  # GAME_OVER or VICTORY
		if Input.is_action_just_pressed("press"):
			_new_game()

# Delegate handlers
func _on_pause_toggle() -> void:
	if get_tree().paused:
		pause_manager.request_resume()
	else:
		pause_manager.request_pause(game_state.state)

func _on_pause_requested() -> void:
	get_tree().paused = true
	hud.set_pause_menu_visible(true, level_manager.max_unlocked_level)

func _on_resume_requested() -> void:
	get_tree().paused = false
	hud.set_pause_menu_visible(false, level_manager.max_unlocked_level)
	if is_instance_valid(ball_manager.held_ball):
		game_state.state = 0  # IDLE
		hud.show_tap_prompt()
	else:
		game_state.state = 1  # PLAYING

func _on_restart_requested() -> void:
	get_tree().paused = false
	hud.set_pause_menu_visible(false, level_manager.max_unlocked_level)
	_new_game()

func _on_level_selected(level: int) -> void:
	get_tree().paused = false
	hud.set_pause_menu_visible(false, level_manager.max_unlocked_level)
	level_manager.select_level(level, grid, paddle, get_viewport_rect().size)

func _on_ball_lost(_ball: Node) -> void:
	if is_instance_valid(_ball):
		_ball.queue_free()

func _on_ball_spawned(_ball: CharacterBody2D) -> void:
	pass

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
			game_state.lives += 1
			hud.set_lives(game_state.lives)

func _on_level_cleared() -> void:
	if game_state.state != 1:  # PLAYING
		return
	game_state.state = 2  # LEVEL_CLEAR
	hud.hide_tap_prompt()
	ball_manager.clear_all()
	powerup_manager.clear_all()
	# Check perfect
	if game_state._lives_lost_this_level == 0 and level_manager.current_level == 1:
		hud.show_perfect()
	level_manager.on_level_cleared(grid, hud)

func _on_launch_held() -> void:
	ball_manager.launch_held()
