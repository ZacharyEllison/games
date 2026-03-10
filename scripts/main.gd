extends Control

const GAMES_FILE := "res://data/games.json"

const BACKGROUND_COLOR := Color("2e3440")
const PANEL_COLOR := Color("3b4252")
const PANEL_ALT_COLOR := Color("434c5e")
const PANEL_BORDER := Color("4c566a")
const TEXT_COLOR := Color("eceff4")
const MUTED_TEXT := Color("d8dee9")
const DEFAULT_ACCENT := Color("88c0d0")

@onready var background: ColorRect = $Background
@onready var eyebrow_label: Label = $Margin/Content/Eyebrow
@onready var title_label: Label = $Margin/Content/Title
@onready var subtitle_label: Label = $Margin/Content/Subtitle
@onready var game_panel: PanelContainer = $Margin/Content/Panels/GamePanel
@onready var game_header_label: Label = $Margin/Content/Panels/GamePanel/GameMargin/GameBox/GameHeader
@onready var game_hint_label: Label = $Margin/Content/Panels/GamePanel/GameMargin/GameBox/GameHint
@onready var game_list: VBoxContainer = $Margin/Content/Panels/GamePanel/GameMargin/GameBox/GameScroll/GameList
@onready var details_panel: PanelContainer = $Margin/Content/Panels/DetailsPanel
@onready var status_label: Label = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/StatusLabel
@onready var selected_title_label: Label = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/SelectedTitle
@onready var accent_bar: ColorRect = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/AccentBar
@onready var description_label: Label = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/SelectedDescription
@onready var hint_panel: PanelContainer = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/HintPanel
@onready var target_label: Label = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/HintPanel/HintMargin/TargetLabel
@onready var play_button: Button = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/PlayButton

var games: Array[Dictionary] = []
var game_buttons: Array[Button] = []
var button_group := ButtonGroup.new()
var selected_game_index := -1

func _ready() -> void:
	_apply_theme()
	play_button.pressed.connect(_on_play_pressed)
	games = _load_games()
	_populate_games()

func _apply_theme() -> void:
	background.color = BACKGROUND_COLOR

	_set_label_style(eyebrow_label, 13, DEFAULT_ACCENT)
	eyebrow_label.text = "WEB ARCADE"
	_set_label_style(title_label, 42, TEXT_COLOR)
	_set_label_style(subtitle_label, 17, MUTED_TEXT)
	_set_label_style(game_header_label, 24, TEXT_COLOR)
	_set_label_style(game_hint_label, 14, MUTED_TEXT)
	_set_label_style(status_label, 13, DEFAULT_ACCENT)
	_set_label_style(selected_title_label, 32, TEXT_COLOR)
	_set_label_style(description_label, 16, MUTED_TEXT)
	_set_label_style(target_label, 14, MUTED_TEXT)

	_apply_panel_style(game_panel, PANEL_COLOR)
	_apply_panel_style(details_panel, PANEL_ALT_COLOR)
	_apply_panel_style(hint_panel, Color("2e3440"))
	_apply_action_button_style(play_button, DEFAULT_ACCENT)

func _load_games() -> Array[Dictionary]:
	if not FileAccess.file_exists(GAMES_FILE):
		return []

	var raw_text := FileAccess.get_file_as_string(GAMES_FILE)
	var parsed = JSON.parse_string(raw_text)
	if not (parsed is Array):
		return []

	var result: Array[Dictionary] = []
	for item in parsed:
		if item is Dictionary:
			result.append(item)
	return result

func _populate_games() -> void:
	for child in game_list.get_children():
		child.queue_free()
	game_buttons.clear()
	selected_game_index = -1

	if games.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No games are registered yet.\nAdd entries to data/games.json."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_set_label_style(empty_label, 15, MUTED_TEXT)
		game_list.add_child(empty_label)

		status_label.text = "EMPTY"
		selected_title_label.text = "No game selected"
		description_label.text = "The launcher has no registered web exports yet."
		target_label.text = "Launch target:\ndata/games.json"
		play_button.text = "Nothing to play"
		play_button.disabled = true
		accent_bar.color = PANEL_BORDER
		return

	for index in range(games.size()):
		var game := games[index]
		var button := Button.new()
		button.text = String(game.get("title", "Untitled Game"))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = button_group
		button.focus_mode = Control.FOCUS_ALL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 54)
		_apply_list_button_style(button)
		button.pressed.connect(_on_game_selected.bind(index))
		game_list.add_child(button)
		game_buttons.append(button)

	_select_game(0)

func _on_game_selected(index: int) -> void:
	_select_game(index)

func _select_game(index: int) -> void:
	if index < 0 or index >= games.size():
		return

	selected_game_index = index
	var game := games[index]
	var accent := _game_accent(game)

	for button_index in range(game_buttons.size()):
		game_buttons[button_index].button_pressed = button_index == index

	status_label.text = String(game.get("status", "Ready")).to_upper()
	status_label.add_theme_color_override("font_color", accent)
	selected_title_label.text = String(game.get("title", "Untitled Game"))
	description_label.text = String(game.get("description", ""))
	target_label.text = "Launch target:\n%s\n\nUse browser back to return to the arcade." % String(game.get("url", ""))
	accent_bar.color = accent
	play_button.text = "Play %s" % String(game.get("title", "Game"))
	play_button.disabled = false
	_apply_action_button_style(play_button, accent)

func _on_play_pressed() -> void:
	if selected_game_index < 0 or selected_game_index >= games.size():
		return

	var target := String(games[selected_game_index].get("url", ""))
	if target.is_empty():
		return

	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = %s;" % JSON.stringify(target))
		return

	var native_target := target.trim_prefix("./")
	OS.shell_open(ProjectSettings.globalize_path("res://%s" % native_target))

func _set_label_style(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

func _apply_panel_style(panel: PanelContainer, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = PANEL_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_right = 24
	style.corner_radius_bottom_left = 24
	panel.add_theme_stylebox_override("panel", style)

func _apply_list_button_style(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.add_theme_color_override("font_focus_color", TEXT_COLOR)

	button.add_theme_stylebox_override("normal", _button_style(Color("434c5e"), PANEL_BORDER))
	button.add_theme_stylebox_override("hover", _button_style(Color("4c566a"), Color("81a1c1")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("4c566a"), DEFAULT_ACCENT))
	button.add_theme_stylebox_override("focus", _button_style(Color("4c566a"), DEFAULT_ACCENT))
	button.add_theme_stylebox_override("disabled", _button_style(Color("3b4252"), PANEL_BORDER))

func _apply_action_button_style(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("2e3440"))
	button.add_theme_color_override("font_hover_color", Color("2e3440"))
	button.add_theme_color_override("font_pressed_color", Color("2e3440"))
	button.add_theme_color_override("font_focus_color", Color("2e3440"))

	button.add_theme_stylebox_override("normal", _button_style(accent, accent.darkened(0.12), 26))
	button.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.08), accent.darkened(0.05), 26))
	button.add_theme_stylebox_override("pressed", _button_style(accent.darkened(0.08), accent.darkened(0.16), 26))
	button.add_theme_stylebox_override("focus", _button_style(accent.lightened(0.08), accent.darkened(0.05), 26))
	button.add_theme_stylebox_override("disabled", _button_style(Color("4c566a"), PANEL_BORDER, 26))

func _button_style(fill: Color, border: Color, radius: int = 20) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 18
	style.content_margin_top = 12
	style.content_margin_right = 18
	style.content_margin_bottom = 12
	return style

func _game_accent(game: Dictionary) -> Color:
	return Color.from_string(String(game.get("accent", "")), DEFAULT_ACCENT)
