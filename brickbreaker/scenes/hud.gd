extends CanvasLayer

const RAINBOW_SHADER := preload("res://shaders/rainbow_shimmer.gdshader")
const COMIC_FONT := preload("res://fonts/ComicNeue-Bold.ttf")
const MAX_LEVEL := 10

@onready var score_label: Label = $Score
@onready var lives_label: Label = $Lives
@onready var message: Label = $Message
@onready var tap_prompt: Label = $TapPrompt
@onready var final_score: Label = $GameOverPanel/FinalScore
@onready var bang_backdrop: Control = $GameOverPanel/BangBackdrop
@onready var game_over_panel: Control = $GameOverPanel
@onready var perfect_badge: Label = $PerfectBadge
@onready var pause_btn: Button = $PauseBtn
@onready var pause_overlay: ColorRect = $PauseOverlay
@onready var pause_menu: VBoxContainer = $PauseOverlay/PauseMenu
@onready var level_select_grid: GridContainer = $PauseOverlay/LevelSelectPanel/VBox/Grid
@onready var level_select_panel: PanelContainer = $PauseOverlay/LevelSelectPanel
@onready var floating_layer: Control = $FloatingLayer

var _rainbow_mat: ShaderMaterial
var _gold_mat: ShaderMaterial
var _float_tweens: Dictionary = {}

signal pause_requested
signal resume_requested
signal restart_requested
signal level_selected(level: int)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and pause_overlay.visible:
		resume_requested.emit()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rainbow_mat = ShaderMaterial.new()
	_rainbow_mat.shader = RAINBOW_SHADER
	_rainbow_mat.set_shader_parameter("speed", 2.0)
	_rainbow_mat.set_shader_parameter("gold_mode", 0.0)
	_gold_mat = ShaderMaterial.new()
	_gold_mat.shader = RAINBOW_SHADER
	_gold_mat.set_shader_parameter("speed", 2.5)
	_gold_mat.set_shader_parameter("gold_mode", 1.0)
	tap_prompt.hide()
	game_over_panel.hide()
	perfect_badge.hide()
	pause_overlay.hide()
	level_select_panel.hide()
	pause_btn.pressed.connect(_on_pause_btn_pressed)
	$PauseOverlay/PauseMenu/ResumeBtn.pressed.connect(_on_resume)
	$PauseOverlay/PauseMenu/RestartBtn.pressed.connect(func(): restart_requested.emit())
	$PauseOverlay/LevelSelectPanel/VBox/BackBtn.pressed.connect(_hide_level_select)
	$PauseOverlay/PauseMenu/LevelSelectBtn.pressed.connect(_show_level_select)

func set_score(value: int) -> void:
	score_label.text = "SCORE %d" % value
	_bump(score_label)

func set_lives(value: int) -> void:
	lives_label.text = "LIVES %d" % value
	_bump(lives_label)

func slam_score() -> void:
	_slam_in(score_label, 0.15)
	_bump(score_label)

func show_message(text: String) -> void:
	message.text = text
	message.show()
	_slam_in(message, 0.4)

func hide_message() -> void:
	message.hide()

func show_tap_prompt() -> void:
	tap_prompt.show()
	_start_float(tap_prompt)

func hide_tap_prompt() -> void:
	_stop_float(tap_prompt)
	tap_prompt.hide()

func show_game_over(score: int) -> void:
	hide_tap_prompt()
	message.text = "GAME OVER"
	message.show()
	_slam_in(message, 0.4)
	game_over_panel.show()
	final_score.text = "SCORE %d" % score
	final_score.material = null
	bang_backdrop.hide()
	if score > 2000:
		bang_backdrop.show()
	if score > 1000:
		final_score.material = _rainbow_mat
	_slam_in(final_score, 0.3)

func hide_game_over() -> void:
	game_over_panel.hide()
	message.hide()

func show_victory(score: int) -> void:
	hide_tap_prompt()
	hide_game_over()
	message.text = "YOU WIN!"
	message.show()
	_slam_in(message, 0.4)
	game_over_panel.show()
	final_score.text = "SCORE %d" % score
	final_score.material = null
	bang_backdrop.hide()
	if score > 2000:
		bang_backdrop.show()
	if score > 1000:
		final_score.material = _rainbow_mat
	_slam_in(final_score, 0.3)

func hide_victory() -> void:
	hide_game_over()

func show_perfect() -> void:
	perfect_badge.show()
	perfect_badge.material = _gold_mat
	_slam_in(perfect_badge, 0.25)
	_start_float(perfect_badge)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(perfect_badge, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		_stop_float(perfect_badge)
		perfect_badge.hide()
		perfect_badge.modulate.a = 1.0
	)

func show_slam_text(text: String, world_pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", COMIC_FONT)
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(1.0, 0.95, 0.3)
	floating_layer.add_child(label)
	label.position = world_pos - Vector2(80, 14)
	label.size = Vector2(160, 36)
	label.pivot_offset = label.size * 0.5
	_slam_in(label, 0.2)
	var tween := create_tween()
	tween.tween_interval(0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)

func set_pause_menu_visible(visible: bool, max_level: int) -> void:
	if visible:
		pause_overlay.show()
		level_select_panel.hide()
		_animate_pause_menu_in()
		_build_level_buttons(max_level)
	else:
		pause_overlay.hide()
		level_select_panel.hide()

func _build_level_buttons(max_unlocked: int) -> void:
	for child in level_select_grid.get_children():
		child.queue_free()
	for i in range(1, MAX_LEVEL + 1):
		var btn := Button.new()
		btn.text = str(i)
		btn.add_theme_font_override("font", COMIC_FONT)
		btn.custom_minimum_size = Vector2(52, 44)
		var unlocked := i <= max_unlocked
		btn.disabled = not unlocked
		btn.modulate = Color.WHITE if unlocked else Color(0.45, 0.45, 0.5, 0.85)
		if unlocked:
			var lvl := i
			btn.pressed.connect(func(): level_selected.emit(lvl))
		level_select_grid.add_child(btn)

func _show_level_select() -> void:
	pause_menu.hide()
	level_select_panel.show()
	for i in level_select_grid.get_child_count():
		var btn: Button = level_select_grid.get_child(i)
		btn.scale = Vector2(0.3, 0.3)
		btn.pivot_offset = btn.size * 0.5
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(i * 0.04)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.25)

func _hide_level_select() -> void:
	level_select_panel.hide()
	pause_menu.show()

func _animate_pause_menu_in() -> void:
	for i in pause_menu.get_child_count():
		var node: Control = pause_menu.get_child(i)
		if node is Button:
			node.scale = Vector2(0.3, 0.3)
			node.pivot_offset = node.size * 0.5
			var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_interval(i * 0.05)
			tween.tween_property(node, "scale", Vector2.ONE, 0.28)

func _on_pause_btn_pressed() -> void:
	if pause_overlay.visible:
		resume_requested.emit()
	else:
		pause_requested.emit()

func _on_resume() -> void:
	resume_requested.emit()

func _slam_in(node: Control, from_scale: float = 0.2) -> void:
	node.scale = Vector2(from_scale, from_scale)
	node.pivot_offset = node.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(1.1, 1.1), 0.18)
	tween.tween_property(node, "scale", Vector2.ONE, 0.12)

func _start_float(node: Control) -> void:
	_stop_float(node)
	node.pivot_offset = node.size * 0.5
	var base_rot: float = node.rotation
	var base_scale: Vector2 = node.scale
	var rot_tween := create_tween().set_loops()
	rot_tween.tween_property(node, "rotation", base_rot + deg_to_rad(4.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rot_tween.tween_property(node, "rotation", base_rot - deg_to_rad(4.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var scale_tween := create_tween().set_loops()
	scale_tween.tween_property(node, "scale", base_scale * 1.05, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	scale_tween.tween_property(node, "scale", base_scale * 0.95, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tweens[node] = [rot_tween, scale_tween]

func _stop_float(node: Control) -> void:
	if _float_tweens.has(node):
		for t in _float_tweens[node]:
			if t.is_valid():
				t.kill()
		_float_tweens.erase(node)
	node.rotation = 0.0

func _bump(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(1.3, 1.3)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.25)
