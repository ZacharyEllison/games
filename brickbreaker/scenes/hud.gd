extends CanvasLayer

const RAINBOW_SHADER := preload("res://shaders/rainbow_shimmer.gdshader")
const COMIC_FONT := preload("res://fonts/ComicNeue-Bold.ttf")
const MAX_LEVEL := 10
const BRICK_SHARE_NORMAL := preload("res://art/kenney_brick-pack/PNG/Default/Red/brick_medium_1.png")
const BRICK_SHARE_HOVER := preload("res://art/kenney_brick-pack/PNG/Default/Red/brick_medium_2.png")
const BRICK_RESTART_NORMAL := preload("res://art/kenney_brick-pack/PNG/Default/Red/brick_medium_1.png")
const BRICK_RESTART_HOVER := preload("res://art/kenney_brick-pack/PNG/Default/Red/brick_medium_2.png")

@onready var score_label: Label = $Score
@onready var best_score_label: Label = $BestScore
@onready var lives_label: Label = $Lives
@onready var action_buttons: HBoxContainer = $GameOverPanel/Content/ActionButtons
@onready var restart_btn: Button = $GameOverPanel/Content/ActionButtons/RestartBtn
@onready var title_label: Label = $GameOverPanel/Content/TitleLabel
@onready var final_score: Label = $GameOverPanel/Content/FinalScore
@onready var best_score_line: Label = $GameOverPanel/Content/BestScoreLine
@onready var new_best_badge: Label = $GameOverPanel/Content/NewBestBadge
@onready var stats_line: Label = $GameOverPanel/Content/StatsLine
@onready var share_btn: Button = $GameOverPanel/Content/ActionButtons/ShareBtn
@onready var share_confirm: Label = $GameOverPanel/Content/ShareConfirm
@onready var bang_backdrop: Control = $GameOverPanel/BangBackdrop
@onready var game_over_panel: MarginContainer = $GameOverPanel
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
var _share_stylebox: StyleBoxTexture
var _restart_stylebox: StyleBoxTexture

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
	game_over_panel.hide()
	perfect_badge.hide()
	new_best_badge.hide()
	pause_overlay.hide()
	level_select_panel.hide()
	pause_btn.pressed.connect(_on_pause_btn_pressed)
	$PauseOverlay/PauseMenu/ResumeBtn.pressed.connect(_on_resume)
	$PauseOverlay/PauseMenu/RestartBtn.pressed.connect(func(): restart_requested.emit())
	$PauseOverlay/LevelSelectPanel/VBox/BackBtn.pressed.connect(_hide_level_select)
	$PauseOverlay/PauseMenu/LevelSelectBtn.pressed.connect(_show_level_select)
	share_btn.pressed.connect(_on_share_pressed)
	restart_btn.pressed.connect(func(): restart_requested.emit())

	# Share button brick style
	_share_stylebox = StyleBoxTexture.new()
	_share_stylebox.texture = BRICK_SHARE_NORMAL
	_share_stylebox.set_expand_margin_all(4.0)
	share_btn.add_theme_stylebox_override("normal", _share_stylebox)
	share_btn.add_theme_stylebox_override("hover", _share_hover_style())
	share_btn.add_theme_constant_override("outline_size", 2)
	share_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

	# Restart button brick style
	var restart_stylebox := StyleBoxTexture.new()
	restart_stylebox.texture = BRICK_RESTART_NORMAL
	restart_stylebox.set_expand_margin_all(4.0)
	restart_btn.add_theme_stylebox_override("normal", restart_stylebox)
	restart_btn.add_theme_stylebox_override("hover", _restart_hover_style())
	restart_btn.add_theme_constant_override("outline_size", 2)
	restart_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

func set_score(value: int) -> void:
	score_label.text = "SCORE %d" % value
	_bump(score_label)

func set_high_score(value: int) -> void:
	best_score_label.text = "BEST %d" % value

func set_lives(value: int) -> void:
	lives_label.text = "LIVES %d" % value
	_bump(lives_label)

func slam_score() -> void:
	_slam_in(score_label, 0.15)
	_bump(score_label)

func show_game_over(score: int, high_score: int, new_best: bool, games_played: int, games_won: int) -> void:
	game_over_panel.show()
	title_label.text = "GAME OVER"
	_show_end_panel(score, high_score, new_best, games_played, games_won)

func hide_game_over() -> void:
	game_over_panel.hide()
	title_label.hide()
	new_best_badge.hide()
	share_confirm.hide()

func show_victory(score: int, high_score: int, new_best: bool, games_played: int, games_won: int) -> void:
	hide_game_over()
	title_label.text = "YOU WIN!"
	game_over_panel.show()
	_show_end_panel(score, high_score, new_best, games_played, games_won)

func hide_victory() -> void:
	hide_game_over()

func _show_end_panel(score: int, high_score: int, new_best: bool, games_played: int, games_won: int) -> void:
	share_btn.show()
	share_confirm.hide()
	final_score.text = "SCORE %d" % score
	final_score.material = null
	best_score_line.text = "BEST %d" % high_score
	stats_line.text = "Games: %d · Wins: %d" % [games_played, games_won]
	new_best_badge.visible = new_best
	bang_backdrop.hide()
	if score > 2000:
		bang_backdrop.show()
	if score > 1000:
		final_score.material = _rainbow_mat
	_slam_in(final_score, 0.3)
	_slam_in(title_label, 0.3)
	if new_best:
		new_best_badge.material = _gold_mat
		_slam_in(new_best_badge, 0.25)

func show_perfect() -> void:
	perfect_badge.show()
	perfect_badge.material = _gold_mat
	_slam_in(perfect_badge, 0.25)
	_start_float(perfect_badge)

func hide_perfect() -> void:
	_stop_float(perfect_badge)
	perfect_badge.hide()
	perfect_badge.modulate.a = 1.0

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

func show_level_transition(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", COMIC_FONT)
	label.add_theme_font_size_override("font_size", 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	floating_layer.add_child(label)
	label.size = Vector2(320, 60)
	label.position = Vector2(-160, -30)
	label.pivot_offset = label.size * 0.5
	_slam_in(label, 0.3)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)

func _animate_button_press(btn: Button) -> void:
	var orig_scale := btn.scale
	var tween := create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", orig_scale * 0.85, 0.08)
	tween.tween_property(btn, "scale", orig_scale, 0.18)

func _on_share_pressed() -> void:
	_animate_button_press(share_btn)
	var score_text := final_score.text.split(" ")[1]
	var best_text := best_score_line.text.split(" ")[1]
	var msg := "I scored %s points in Brickbreaker! Best: %s.\nCan you beat me?" % [score_text, best_text]
	DisplayServer.clipboard_set(msg)
	share_confirm.show()
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(share_confirm, "modulate:a", 0.0, 0.3)
	tween.tween_callback(share_confirm.hide)
	var btn_tween := create_tween()
	btn_tween.tween_property(share_btn, "modulate:a", 0.5, 0.1)
	btn_tween.tween_property(share_btn, "modulate:a", 1.0, 0.2)

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

func _share_hover_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = BRICK_SHARE_HOVER
	sb.set_expand_margin_all(4.0)
	return sb

func _restart_hover_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = BRICK_RESTART_HOVER
	sb.set_expand_margin_all(4.0)
	return sb
