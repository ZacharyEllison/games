extends Control

const GAMES_FILE := "res://data/games.json"

const BACKGROUND_COLOR := Color("eceff4")
const PANEL_COLOR := Color("e5e9f0")
const PANEL_ALT_COLOR := Color("dde4ee")
const PANEL_BORDER := Color("c8d2df")
const TEXT_COLOR := Color("2e3440")
const MUTED_TEXT := Color("4c566a")
const SURFACE_COLOR := Color("f7f9fc")
const LIST_BUTTON_COLOR := Color("edf2f7")
const LIST_BUTTON_HOVER_COLOR := Color("e3eaf3")
const LIST_BUTTON_ACTIVE_COLOR := Color("d7e4f2")
const DEFAULT_ACCENT := Color("81a1c1")

@onready var background: ColorRect = $Background
@onready var margin_container: MarginContainer = $Margin
@onready var content_box: VBoxContainer = $Margin/Content
@onready var eyebrow_label: Label = $Margin/Content/Eyebrow
@onready var title_label: Label = $Margin/Content/Title
@onready var subtitle_label: Label = $Margin/Content/Subtitle
@onready var panels_box: VBoxContainer = $Margin/Content/Panels
@onready var game_panel: PanelContainer = $Margin/Content/Panels/GamePanel
@onready var game_margin: MarginContainer = $Margin/Content/Panels/GamePanel/GameMargin
@onready var game_box: VBoxContainer = $Margin/Content/Panels/GamePanel/GameMargin/GameBox
@onready var game_header_label: Label = $Margin/Content/Panels/GamePanel/GameMargin/GameBox/GameHeader
@onready var game_hint_label: Label = $Margin/Content/Panels/GamePanel/GameMargin/GameBox/GameHint
@onready var game_scroll: ScrollContainer = $Margin/Content/Panels/GamePanel/GameMargin/GameBox/GameScroll
@onready var game_list: VBoxContainer = $Margin/Content/Panels/GamePanel/GameMargin/GameBox/GameScroll/GameList
@onready var details_panel: PanelContainer = $Margin/Content/Panels/DetailsPanel
@onready var details_margin: MarginContainer = $Margin/Content/Panels/DetailsPanel/DetailsMargin
@onready var details_box: VBoxContainer = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox
@onready var status_label: Label = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/StatusLabel
@onready var selected_title_label: Label = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/SelectedTitle
@onready var accent_bar: ColorRect = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/AccentBar
@onready var description_label: Label = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/SelectedDescription
@onready var hint_panel: PanelContainer = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/HintPanel
@onready var hint_margin: MarginContainer = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/HintPanel/HintMargin
@onready var target_label: Label = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/HintPanel/HintMargin/TargetLabel
@onready var play_button: Button = $Margin/Content/Panels/DetailsPanel/DetailsMargin/DetailsBox/PlayButton

var games: Array[Dictionary] = []
var game_buttons: Array[Button] = []
var button_group := ButtonGroup.new()
var selected_game_index := -1

func _ready() -> void:
	_apply_theme()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	play_button.pressed.connect(_on_play_pressed)
	games = _load_games()
	_populate_games()
	_apply_responsive_layout()

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
	_apply_panel_style(hint_panel, SURFACE_COLOR)
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
		play_button.text = "Nothing to play"
		play_button.disabled = true
		accent_bar.color = PANEL_BORDER
		_refresh_copy()
		_apply_responsive_layout()
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
	_apply_responsive_layout()

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
	accent_bar.color = accent
	play_button.text = "Play %s" % String(game.get("title", "Game"))
	play_button.disabled = false
	_apply_action_button_style(play_button, accent)
	_refresh_copy()

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

func _layout_viewport_size() -> Vector2:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size

	if OS.has_feature("web"):
		var js_width := JavaScriptBridge.eval("window.visualViewport ? window.visualViewport.width : window.innerWidth", true)
		var js_height := JavaScriptBridge.eval("window.visualViewport ? window.visualViewport.height : window.innerHeight", true)
		var width := _variant_to_float(js_width, viewport_size.x)
		var height := _variant_to_float(js_height, viewport_size.y)
		if width > 0.0 and height > 0.0:
			return Vector2(width, height)

	return viewport_size

func _variant_to_float(value: Variant, fallback: float) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)

	var parsed := String(value).to_float()
	return parsed if parsed > 0.0 else fallback

func _is_portrait_phone_layout(viewport_size: Vector2) -> bool:
	return viewport_size.x <= 600.0 and viewport_size.y > viewport_size.x * 1.15

func _refresh_copy() -> void:
	var compact_layout := _is_portrait_phone_layout(get_viewport_rect().size)
	subtitle_label.text = "Pick a game and launch it." if compact_layout else "Pick a game, then launch its web build."
	game_hint_label.text = "Choose a game to launch." if compact_layout else "Add future web exports by updating data/games.json and re-exporting this project."

	if games.is_empty():
		target_label.text = "Launch target:\ndata/games.json"
		return

	if selected_game_index >= 0 and selected_game_index < games.size():
		target_label.text = _target_label_text(String(games[selected_game_index].get("url", "")), compact_layout)
		return

	target_label.text = "Launch target:"

func _target_label_text(target: String, compact_layout: bool) -> String:
	if compact_layout:
		return "Launch target:\n%s\n\nUse browser back to return." % target
	return "Launch target:\n%s\n\nUse browser back to return to the arcade." % target

func _apply_responsive_layout() -> void:
	var viewport_size := _layout_viewport_size()
	var width := viewport_size.x
	var height := viewport_size.y
	var short_side := minf(width, height)
	var is_phone := width <= 600.0
	var is_portrait_phone := _is_portrait_phone_layout(viewport_size)
	var is_small := width <= 820.0
	var game_count := maxi(game_buttons.size(), maxi(games.size(), 1))
	var outer_margin := int(clampf(short_side * (0.022 if is_portrait_phone else 0.03), 8.0, 24.0))
	var inner_margin := int(clampf(short_side * (0.03 if is_portrait_phone else 0.035), 12.0, 22.0))
	var hint_margin_size := int(clampf(short_side * 0.026, 10.0, 18.0))
	var section_spacing := int(clampf(short_side * (0.018 if is_portrait_phone else 0.022), 8.0, 18.0))
	var list_spacing := int(clampf(short_side * 0.022, 8.0, 16.0))
	var title_size := int(clampf(short_side * (0.115 if is_portrait_phone else 0.082), 30.0, 60.0))
	var heading_size := int(clampf(short_side * (0.068 if is_portrait_phone else 0.054), 22.0, 34.0))
	var body_size := int(clampf(short_side * (0.052 if is_portrait_phone else 0.04), 16.0, 24.0))
	var helper_size := int(clampf(short_side * (0.04 if is_portrait_phone else 0.033), 13.0, 18.0))
	var status_size := int(clampf(short_side * 0.034, 13.0, 18.0))
	var button_font_size := int(clampf(short_side * (0.05 if is_portrait_phone else 0.04), 16.0, 24.0))
	var button_height := clampf(height * (0.066 if is_portrait_phone else (0.058 if is_phone else 0.05)), 52.0, 76.0)
	var play_height := clampf(height * (0.072 if is_portrait_phone else (0.064 if is_phone else 0.056)), 56.0, 82.0)
	var game_list_content_height := game_count * button_height + maxi(game_count - 1, 0) * float(list_spacing)
	var game_list_height := clampf(game_list_content_height, button_height, height * (0.24 if is_portrait_phone else (0.32 if is_phone else 0.36)))
	var game_panel_flags := Control.SIZE_FILL if is_portrait_phone else Control.SIZE_EXPAND_FILL
	var game_scroll_flags := Control.SIZE_FILL if is_portrait_phone else Control.SIZE_EXPAND_FILL

	margin_container.add_theme_constant_override("margin_left", outer_margin)
	margin_container.add_theme_constant_override("margin_top", outer_margin)
	margin_container.add_theme_constant_override("margin_right", outer_margin)
	margin_container.add_theme_constant_override("margin_bottom", outer_margin)

	content_box.add_theme_constant_override("separation", section_spacing)
	panels_box.add_theme_constant_override("separation", section_spacing)
	game_box.add_theme_constant_override("separation", list_spacing)
	game_list.add_theme_constant_override("separation", list_spacing)
	details_box.add_theme_constant_override("separation", int(clampf(short_side * 0.024, 10.0, 18.0)))

	game_margin.add_theme_constant_override("margin_left", inner_margin)
	game_margin.add_theme_constant_override("margin_top", inner_margin)
	game_margin.add_theme_constant_override("margin_right", inner_margin)
	game_margin.add_theme_constant_override("margin_bottom", inner_margin)
	details_margin.add_theme_constant_override("margin_left", inner_margin)
	details_margin.add_theme_constant_override("margin_top", inner_margin)
	details_margin.add_theme_constant_override("margin_right", inner_margin)
	details_margin.add_theme_constant_override("margin_bottom", inner_margin)
	hint_margin.add_theme_constant_override("margin_left", hint_margin_size)
	hint_margin.add_theme_constant_override("margin_top", hint_margin_size)
	hint_margin.add_theme_constant_override("margin_right", hint_margin_size)
	hint_margin.add_theme_constant_override("margin_bottom", hint_margin_size)

	game_scroll.custom_minimum_size = Vector2(0.0, game_list_height)
	game_scroll.size_flags_vertical = game_scroll_flags
	play_button.custom_minimum_size = Vector2(0.0, play_height)
	accent_bar.custom_minimum_size = Vector2(0.0, 5.0 if is_portrait_phone else 6.0)
	game_panel.size_flags_vertical = game_panel_flags
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_set_label_style(eyebrow_label, helper_size, DEFAULT_ACCENT)
	_set_label_style(title_label, title_size, TEXT_COLOR)
	_set_label_style(subtitle_label, body_size, MUTED_TEXT)
	_set_label_style(game_header_label, heading_size, TEXT_COLOR)
	_set_label_style(game_hint_label, helper_size, MUTED_TEXT)
	_set_label_style(status_label, status_size, status_label.get_theme_color("font_color", "Label"))
	_set_label_style(selected_title_label, int(clampf(title_size * 0.78, 28.0, 46.0)), TEXT_COLOR)
	_set_label_style(description_label, body_size, MUTED_TEXT)
	_set_label_style(target_label, helper_size, MUTED_TEXT)
	_refresh_copy()

	for button in game_buttons:
		button.add_theme_font_size_override("font_size", button_font_size)
		button.custom_minimum_size = Vector2(0.0, button_height)

	play_button.add_theme_font_size_override("font_size", int(clampf(button_font_size + 1, 18.0, 26.0)))

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

	button.add_theme_stylebox_override("normal", _button_style(LIST_BUTTON_COLOR, PANEL_BORDER))
	button.add_theme_stylebox_override("hover", _button_style(LIST_BUTTON_HOVER_COLOR, DEFAULT_ACCENT))
	button.add_theme_stylebox_override("pressed", _button_style(LIST_BUTTON_ACTIVE_COLOR, DEFAULT_ACCENT))
	button.add_theme_stylebox_override("focus", _button_style(LIST_BUTTON_ACTIVE_COLOR, DEFAULT_ACCENT))
	button.add_theme_stylebox_override("disabled", _button_style(PANEL_COLOR, PANEL_BORDER))

func _apply_action_button_style(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.add_theme_color_override("font_focus_color", TEXT_COLOR)

	var base_fill := accent.lightened(0.22)
	button.add_theme_stylebox_override("normal", _button_style(base_fill, accent, 26))
	button.add_theme_stylebox_override("hover", _button_style(base_fill.lightened(0.08), accent.darkened(0.05), 26))
	button.add_theme_stylebox_override("pressed", _button_style(accent.lightened(0.12), accent.darkened(0.08), 26))
	button.add_theme_stylebox_override("focus", _button_style(base_fill.lightened(0.08), accent.darkened(0.05), 26))
	button.add_theme_stylebox_override("disabled", _button_style(PANEL_ALT_COLOR, PANEL_BORDER, 26))

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
