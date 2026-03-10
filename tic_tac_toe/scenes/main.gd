extends Control

const BOARD_WIDTH := 3
const EMPTY_CELL := ""
const WIN_LINES := [
	PackedInt32Array([0, 1, 2]),
	PackedInt32Array([3, 4, 5]),
	PackedInt32Array([6, 7, 8]),
	PackedInt32Array([0, 3, 6]),
	PackedInt32Array([1, 4, 7]),
	PackedInt32Array([2, 5, 8]),
	PackedInt32Array([0, 4, 8]),
	PackedInt32Array([2, 4, 6]),
]

const BACKGROUND_COLOR := Color8(28, 31, 43)
const PANEL_COLOR := Color8(36, 50, 74)
const PANEL_BORDER_COLOR := Color8(77, 110, 163)
const TILE_IDLE_COLOR := Color8(49, 72, 105)
const TILE_LOCKED_COLOR := Color8(41, 54, 77)
const TEXT_COLOR := Color8(244, 247, 251)
const MUTED_TEXT_COLOR := Color8(168, 179, 201)
const PLAYER_X_COLOR := Color8(255, 134, 104)
const PLAYER_O_COLOR := Color8(90, 212, 195)
const HIGHLIGHT_COLOR := Color8(240, 199, 94)
const DARK_TEXT_COLOR := Color8(30, 34, 48)

var board: Array[String] = []
var cells: Array[Button] = []
var current_player := "X"
var starting_player := "X"
var game_over := false
var highlighted_line := PackedInt32Array()
var scores := {
	"X": 0,
	"O": 0,
	"Draws": 0,
}

var status_label: Label
var score_label: Label


func _ready() -> void:
	Input.set_emulate_touch_from_mouse(true)
	_build_ui()
	_start_round()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = BACKGROUND_COLOR
	add_child(background)

	var shell := MarginContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("margin_left", 24)
	shell.add_theme_constant_override("margin_top", 24)
	shell.add_theme_constant_override("margin_right", 24)
	shell.add_theme_constant_override("margin_bottom", 24)
	add_child(shell)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 18)
	shell.add_child(layout)

	var title := Label.new()
	title.text = "Tic Tac Toe"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	layout.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(status_label)

	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	layout.add_child(score_label)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR, PANEL_BORDER_COLOR, 28, 4))
	layout.add_child(board_panel)

	var board_margin := MarginContainer.new()
	board_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_margin.add_theme_constant_override("margin_left", 18)
	board_margin.add_theme_constant_override("margin_top", 18)
	board_margin.add_theme_constant_override("margin_right", 18)
	board_margin.add_theme_constant_override("margin_bottom", 18)
	board_panel.add_child(board_margin)

	var board_center := CenterContainer.new()
	board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_margin.add_child(board_center)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.0
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_center.add_child(aspect)

	var grid := GridContainer.new()
	grid.columns = BOARD_WIDTH
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	aspect.add_child(grid)

	for index in range(BOARD_WIDTH * BOARD_WIDTH):
		var cell := Button.new()
		cell.focus_mode = Control.FOCUS_NONE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(160, 160)
		cell.add_theme_font_size_override("font_size", 64)
		cell.pressed.connect(_on_cell_pressed.bind(index))
		_style_cell(cell, TILE_IDLE_COLOR, PANEL_BORDER_COLOR, TEXT_COLOR)
		grid.add_child(cell)
		cells.append(cell)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)

	var new_round_button := Button.new()
	new_round_button.text = "New Round"
	new_round_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_round_button.custom_minimum_size = Vector2(0, 64)
	new_round_button.add_theme_font_size_override("font_size", 20)
	_style_action_button(new_round_button, HIGHLIGHT_COLOR, Color8(64, 52, 18), DARK_TEXT_COLOR)
	new_round_button.pressed.connect(_start_round)
	actions.add_child(new_round_button)

	var reset_scores_button := Button.new()
	reset_scores_button.text = "Reset Score"
	reset_scores_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_scores_button.custom_minimum_size = Vector2(0, 64)
	reset_scores_button.add_theme_font_size_override("font_size", 20)
	_style_action_button(reset_scores_button, Color8(72, 92, 126), PANEL_BORDER_COLOR, TEXT_COLOR)
	reset_scores_button.pressed.connect(_reset_scores)
	actions.add_child(reset_scores_button)

	var helper_text := Label.new()
	helper_text.text = "Pass-and-play on one device. Tap any tile to place your mark."
	helper_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	helper_text.add_theme_font_size_override("font_size", 18)
	helper_text.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	helper_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(helper_text)


func _on_cell_pressed(index: int) -> void:
	if game_over or board[index] != EMPTY_CELL:
		return

	board[index] = current_player

	var winner := _find_winner()
	if winner != EMPTY_CELL:
		game_over = true
		scores[winner] += 1
		_set_status("Player %s wins!" % winner, _player_color(winner))
	elif not board.has(EMPTY_CELL):
		game_over = true
		scores["Draws"] += 1
		_set_status("Draw game", HIGHLIGHT_COLOR)
	else:
		current_player = _next_player(current_player)
		_set_status("Player %s's turn" % current_player, _player_color(current_player))

	_refresh_board()
	_refresh_score()


func _start_round() -> void:
	board.clear()
	for _index in range(BOARD_WIDTH * BOARD_WIDTH):
		board.append(EMPTY_CELL)

	current_player = starting_player
	starting_player = _next_player(starting_player)
	game_over = false
	highlighted_line = PackedInt32Array()

	_set_status("Player %s starts" % current_player, _player_color(current_player))
	_refresh_board()
	_refresh_score()


func _reset_scores() -> void:
	scores["X"] = 0
	scores["O"] = 0
	scores["Draws"] = 0
	starting_player = "X"
	_start_round()


func _refresh_board() -> void:
	for index in range(cells.size()):
		var cell := cells[index]
		var mark := board[index]
		var is_highlighted := highlighted_line.has(index)
		var is_locked := mark != EMPTY_CELL or game_over

		cell.text = mark
		cell.disabled = is_locked

		var fill_color := TILE_IDLE_COLOR
		var border_color := PANEL_BORDER_COLOR
		var font_color := TEXT_COLOR

		if mark == "X":
			fill_color = PLAYER_X_COLOR.darkened(0.52)
			border_color = PLAYER_X_COLOR
			font_color = TEXT_COLOR
		elif mark == "O":
			fill_color = PLAYER_O_COLOR.darkened(0.58)
			border_color = PLAYER_O_COLOR
			font_color = TEXT_COLOR
		elif game_over:
			fill_color = TILE_LOCKED_COLOR
			border_color = PANEL_BORDER_COLOR.darkened(0.2)
			font_color = MUTED_TEXT_COLOR

		if is_highlighted:
			fill_color = HIGHLIGHT_COLOR.darkened(0.18)
			border_color = HIGHLIGHT_COLOR
			font_color = DARK_TEXT_COLOR

		_style_cell(cell, fill_color, border_color, font_color)


func _refresh_score() -> void:
	score_label.text = "X %d   O %d   Draws %d" % [scores["X"], scores["O"], scores["Draws"]]


func _find_winner() -> String:
	highlighted_line = PackedInt32Array()

	for line in WIN_LINES:
		var first := board[line[0]]
		if first == EMPTY_CELL:
			continue

		if first == board[line[1]] and first == board[line[2]]:
			highlighted_line = line
			return first

	return EMPTY_CELL


func _next_player(player: String) -> String:
	return "O" if player == "X" else "X"


func _player_color(player: String) -> Color:
	return PLAYER_X_COLOR if player == "X" else PLAYER_O_COLOR


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _style_cell(button: Button, fill_color: Color, border_color: Color, font_color: Color) -> void:
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", font_color)
	button.add_theme_stylebox_override("normal", _make_panel_style(fill_color, border_color, 24, 4))
	button.add_theme_stylebox_override("hover", _make_panel_style(fill_color.lightened(0.08), border_color.lightened(0.1), 24, 4))
	button.add_theme_stylebox_override("pressed", _make_panel_style(fill_color.darkened(0.08), border_color.lightened(0.14), 24, 4))
	button.add_theme_stylebox_override("disabled", _make_panel_style(fill_color, border_color, 24, 4))
	button.add_theme_stylebox_override("focus", _make_panel_style(fill_color, HIGHLIGHT_COLOR, 24, 5))


func _style_action_button(button: Button, fill_color: Color, border_color: Color, font_color: Color) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_stylebox_override("normal", _make_panel_style(fill_color, border_color, 22, 3))
	button.add_theme_stylebox_override("hover", _make_panel_style(fill_color.lightened(0.06), border_color.lightened(0.08), 22, 3))
	button.add_theme_stylebox_override("pressed", _make_panel_style(fill_color.darkened(0.08), border_color.lightened(0.12), 22, 3))
	button.add_theme_stylebox_override("focus", _make_panel_style(fill_color, HIGHLIGHT_COLOR, 22, 4))


func _make_panel_style(fill_color: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
