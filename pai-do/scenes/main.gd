@tool
extends Control

const SHEET_COLLAPSED := 0
const SHEET_EXPANDED := 1
const PLAYER_HOST := "host"
const PLAYER_GUEST := "guest"
const TOKEN_GLYPH_SCENE := preload("res://scenes/token_glyph.tscn")
const TOKEN_DRAG_THRESHOLD := 18.0
const DEBUG_TURN_LOGS := true

const BACKGROUND_COLOR := Color("f7f0e4")
const BOARD_CIRCLE_COLOR := Color("9f8b5b")
const SHEET_COLOR := Color("efe2cf")
const SHEET_BORDER := Color("b48766")
const TILE_CARD_COLOR := Color("f4e8d8")
const TILE_CARD_BORDER := Color("aa8162")
const TEXT_COLOR := Color("4a3427")
const MUTED_TEXT_COLOR := Color("8b725d")
const SLOT_TEXT_COLOR := Color("4f3728")

var tile_defs: Array[Dictionary] = []
var tile_index_by_id := {}

@onready var background: ColorRect = $Background
@onready var header_margin: MarginContainer = $HeaderMargin
@onready var header_box: VBoxContainer = $HeaderMargin/HeaderBox
@onready var eyebrow_label: Label = $HeaderMargin/HeaderBox/EyebrowLabel
@onready var title_button: Button = $HeaderMargin/HeaderBox/TitleButton
@onready var turn_label: Label = $HeaderMargin/HeaderBox/TurnLabel
@onready var rules_modal: Control = $RulesModal
@onready var rules_backdrop: Button = $RulesModal/RulesBackdrop
@onready var rules_center: CenterContainer = $RulesModal/RulesCenter
@onready var rules_panel: PanelContainer = $RulesModal/RulesCenter/RulesPanel
@onready var rules_title_label: Label = $RulesModal/RulesCenter/RulesPanel/RulesPadding/RulesContent/RulesTitle
@onready var objective_text_label: Label = $RulesModal/RulesCenter/RulesPanel/RulesPadding/RulesContent/ObjectiveText
@onready var interaction_text_label: Label = $RulesModal/RulesCenter/RulesPanel/RulesPadding/RulesContent/InteractionText
@onready var close_rules_button: Button = $RulesModal/RulesCenter/RulesPanel/RulesPadding/RulesContent/CloseRulesButton
@onready var board_view: BoardView = $BoardView
@onready var drawer_sheet: PanelContainer = $DrawerSheet
@onready var drawer_padding: MarginContainer = $DrawerSheet/DrawerPadding
@onready var drawer_content: VBoxContainer = $DrawerSheet/DrawerPadding/DrawerContent
@onready var handle_area: Control = $DrawerSheet/DrawerPadding/DrawerContent/HandleArea
@onready var handle_bar: ColorRect = $DrawerSheet/DrawerPadding/DrawerContent/HandleArea/HandleBox/HandleCenter/HandleBar
@onready var drawer_title: Label = $DrawerSheet/DrawerPadding/DrawerContent/HandleArea/HandleBox/DrawerTitle
@onready var tile_scroll: ScrollContainer = $DrawerSheet/DrawerPadding/DrawerContent/TileScroll
@onready var tile_row: HBoxContainer = $DrawerSheet/DrawerPadding/DrawerContent/TileScroll/TileRow

var tile_buttons := {}
var tile_glyphs := {}

var selected_tile_id := ""
var moving_from_slot_id := ""
var current_player_id := PLAYER_HOST
var turn_count := 1
var game_over := false

var sheet_state := SHEET_COLLAPSED
var sheet_current_y := 0.0
var sheet_target_y := 0.0
var sheet_height := 360.0
var peek_height := 92.0
var sheet_dragging := false
var sheet_drag_start_y := 0.0
var sheet_pointer_start_y := 0.0
var sheet_drag_delta := 0.0
var token_drag_pending := false
var token_drag_active := false
var token_drag_pointer_kind := ""
var token_drag_pointer_index := -1
var token_drag_source_kind := ""
var token_drag_tile_id := ""
var token_drag_from_slot_id := ""
var token_drag_source_button: Button
var token_drag_start_position := Vector2.ZERO
var token_drag_pointer_position := Vector2.ZERO
var token_drag_preview: Panel
var token_drag_preview_glyph: TokenGlyph


func _ready() -> void:
	if not Engine.is_editor_hint():
		Input.set_emulate_touch_from_mouse(true)
	_build_data()
	_cache_scene_nodes()
	_build_token_drag_preview()
	_apply_static_theme()
	board_view.set_tile_defs(tile_defs)
	if not resized.is_connected(_layout_scene):
		resized.connect(_layout_scene)
	set_process(not Engine.is_editor_hint())
	set_process_input(not Engine.is_editor_hint())
	_layout_scene()
	_sync_drawer_copy()
	_set_objective_text(_goal_text())
	_set_turn_text(_turn_prompt())
	_set_interaction_text(_default_interaction_text())
	_log_turn("ready", {"turn_prompt": _turn_prompt()})


func _process(delta: float) -> void:
	if sheet_dragging:
		return

	var desired_y := _sheet_rest_y()
	sheet_target_y = desired_y
	var speed := maxf(size.y * 4.5, 1400.0)
	var next_y := move_toward(sheet_current_y, desired_y, delta * speed)
	if absf(next_y - sheet_current_y) > 0.01:
		sheet_current_y = next_y
		_layout_scene()


func _input(event: InputEvent) -> void:
	if not token_drag_pending and not token_drag_active:
		return
	if not _event_matches_drag_pointer(event):
		return

	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		token_drag_pointer_position = _event_position(event)
		if token_drag_pending and token_drag_pointer_position.distance_to(token_drag_start_position) >= TOKEN_DRAG_THRESHOLD:
			_start_token_drag()
		if token_drag_active:
			_update_token_drag()
		return

	if (event is InputEventMouseButton or event is InputEventScreenTouch) and not _is_pointer_pressed(event):
		token_drag_pointer_position = _event_position(event)
		if token_drag_active:
			_finish_token_drag()
		_reset_token_drag_state()


func _build_token_drag_preview() -> void:
	if token_drag_preview != null:
		return

	token_drag_preview = Panel.new()
	token_drag_preview.name = "TokenDragPreview"
	token_drag_preview.top_level = true
	token_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token_drag_preview.visible = false
	token_drag_preview.z_index = 120
	token_drag_preview.size = Vector2.ONE * 92.0
	token_drag_preview.pivot_offset = token_drag_preview.size * 0.5
	token_drag_preview.self_modulate = Color(1.0, 1.0, 1.0, 0.96)

	token_drag_preview_glyph = TOKEN_GLYPH_SCENE.instantiate() as TokenGlyph
	token_drag_preview_glyph.name = "PreviewGlyph"
	token_drag_preview_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	token_drag_preview_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token_drag_preview.add_child(token_drag_preview_glyph)
	add_child(token_drag_preview)


func _build_data() -> void:
	tile_defs = [
		{"id": "lotus", "name": "Lotus", "code": "LT", "accent": Color("b46f58")},
		{"id": "bell_flower", "name": "Bell Flower", "code": "BF", "accent": Color("9c7666")},
		{"id": "lily", "name": "Lily", "code": "LY", "accent": Color("b79b7d")},
		{"id": "beetle", "name": "Beetle", "code": "BT", "accent": Color("8c694f")},
		{"id": "coin", "name": "Metal Coin", "code": "MC", "accent": Color("b28743")},
		{"id": "road", "name": "Road", "code": "RD", "accent": Color("7c6d62")},
		{"id": "sun", "name": "Sun", "code": "SN", "accent": Color("c98b33")},
		{"id": "dharma", "name": "Dharma", "code": "DH", "accent": Color("9a5f2f")},
		{"id": "moon", "name": "Moon", "code": "MN", "accent": Color("6e6a74")},
	]

	for index in range(tile_defs.size()):
		tile_index_by_id[String(tile_defs[index]["id"])] = index


func _cache_scene_nodes() -> void:
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	board_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	drawer_sheet.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	header_box.add_theme_constant_override("separation", 4)
	eyebrow_label.text = "PAI-DO PROTOTYPE"
	title_button.text = "pai-do"
	title_button.flat = true
	title_button.focus_mode = Control.FOCUS_NONE
	title_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	title_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if not title_button.pressed.is_connected(_open_rules_modal):
		title_button.pressed.connect(_open_rules_modal)
	turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rules_modal.visible = false
	rules_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules_modal.z_index = 100
	rules_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules_backdrop.flat = true
	rules_backdrop.disabled = true
	rules_backdrop.focus_mode = Control.FOCUS_NONE
	rules_backdrop.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rules_backdrop.text = ""
	if not rules_backdrop.pressed.is_connected(_close_rules_modal):
		rules_backdrop.pressed.connect(_close_rules_modal)
	rules_title_label.text = "How to Tend the Garden"
	rules_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_rules_button.focus_mode = Control.FOCUS_NONE
	if not close_rules_button.pressed.is_connected(_close_rules_modal):
		close_rules_button.pressed.connect(_close_rules_modal)
	if not board_view.slot_activated.is_connected(_on_board_slot_activated):
		board_view.slot_activated.connect(_on_board_slot_activated)
	if not board_view.slot_gui_input.is_connected(_on_board_slot_gui_input):
		board_view.slot_gui_input.connect(_on_board_slot_gui_input)
	drawer_sheet.clip_contents = true
	if not drawer_sheet.gui_input.is_connected(_on_drawer_sheet_gui_input):
		drawer_sheet.gui_input.connect(_on_drawer_sheet_gui_input)
	drawer_padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawer_content.add_theme_constant_override("separation", 8)
	handle_area.custom_minimum_size = Vector2(0.0, 58.0)
	handle_area.mouse_filter = Control.MOUSE_FILTER_STOP
	if not handle_area.gui_input.is_connected(_on_handle_area_gui_input):
		handle_area.gui_input.connect(_on_handle_area_gui_input)
	drawer_title.visible = false
	drawer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drawer_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_scroll.follow_focus = true
	tile_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tile_row.add_theme_constant_override("separation", 12)
	tile_buttons.clear()
	tile_glyphs.clear()

	for tile in tile_defs:
		var tile_id := String(tile["id"])
		var button_name := "%sButton" % _tile_node_key(tile_id)
		var glyph_name := "%sToken" % _tile_node_key(tile_id)
		var button := tile_row.get_node(button_name) as Button
		var glyph := button.get_node(glyph_name) as TokenGlyph
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.tooltip_text = String(tile["name"])
		button.text = ""
		var press_callable := _on_tile_pressed.bind(tile_id)
		var input_callable := _on_tile_button_gui_input.bind(tile_id)
		if not button.pressed.is_connected(press_callable):
			button.pressed.connect(press_callable)
		if not button.gui_input.is_connected(input_callable):
			button.gui_input.connect(input_callable)
		tile_buttons[tile_id] = button
		tile_glyphs[tile_id] = glyph


func _apply_static_theme() -> void:
	background.color = BACKGROUND_COLOR
	handle_bar.color = Color("a57c5f")

	var sheet_style := StyleBoxFlat.new()
	sheet_style.bg_color = SHEET_COLOR
	sheet_style.border_color = SHEET_BORDER
	sheet_style.set_border_width_all(2)
	sheet_style.corner_radius_top_left = 30
	sheet_style.corner_radius_top_right = 30
	sheet_style.shadow_color = Color(0.45, 0.29, 0.16, 0.12)
	sheet_style.shadow_size = 12
	drawer_sheet.add_theme_stylebox_override("panel", sheet_style)


func _layout_scene() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var outer_margin := clampf(viewport_size.x * 0.05, 18.0, 30.0)
	var header_height := clampf(viewport_size.y * 0.09, 78.0, 120.0)
	var header_top := clampf(viewport_size.y * 0.018, 12.0, 22.0)
	var board_gap := clampf(viewport_size.y * 0.012, 8.0, 16.0)

	sheet_height = clampf(viewport_size.y * 0.3, 286.0, 390.0)
	peek_height = clampf(viewport_size.y * 0.09, 90.0, 118.0)
	var collapsed_y := viewport_size.y - peek_height
	var expanded_y := viewport_size.y - sheet_height

	if sheet_current_y == 0.0:
		sheet_current_y = collapsed_y

	sheet_current_y = clampf(sheet_current_y, expanded_y, collapsed_y)
	sheet_target_y = expanded_y if sheet_state == SHEET_EXPANDED else collapsed_y

	header_margin.position = Vector2(0.0, header_top)
	header_margin.size = Vector2(viewport_size.x, header_height)
	header_margin.add_theme_constant_override("margin_left", int(outer_margin))
	header_margin.add_theme_constant_override("margin_top", 0)
	header_margin.add_theme_constant_override("margin_right", int(outer_margin))
	header_margin.add_theme_constant_override("margin_bottom", 0)

	drawer_sheet.position = Vector2(0.0, sheet_current_y)
	drawer_sheet.size = Vector2(viewport_size.x, sheet_height)
	drawer_padding.add_theme_constant_override("margin_left", int(outer_margin))
	drawer_padding.add_theme_constant_override("margin_top", 10)
	drawer_padding.add_theme_constant_override("margin_right", int(outer_margin))
	drawer_padding.add_theme_constant_override("margin_bottom", int(maxf(18.0, outer_margin)))

	var board_top := header_margin.position.y + header_height + board_gap
	var board_bottom := sheet_current_y - board_gap
	var board_height := maxf(300.0, board_bottom - board_top)
	board_view.position = Vector2(outer_margin, board_top)
	board_view.size = Vector2(viewport_size.x - outer_margin * 2.0, board_height)

	var title_size := int(clampf(viewport_size.x * 0.072, 30.0, 46.0))
	var eyebrow_size := int(clampf(viewport_size.x * 0.024, 12.0, 16.0))
	var turn_size := int(clampf(viewport_size.x * 0.034, 16.0, 21.0))
	var drawer_title_size := int(clampf(viewport_size.x * 0.04, 18.0, 22.0))
	var modal_title_size := int(clampf(viewport_size.x * 0.046, 24.0, 32.0))
	var modal_body_size := int(clampf(viewport_size.x * 0.031, 15.0, 19.0))
	var close_button_size := int(clampf(viewport_size.x * 0.032, 15.0, 18.0))

	eyebrow_label.add_theme_font_size_override("font_size", eyebrow_size)
	eyebrow_label.add_theme_color_override("font_color", BOARD_CIRCLE_COLOR)

	title_button.add_theme_font_size_override("font_size", title_size)
	title_button.add_theme_color_override("font_color", TEXT_COLOR)
	title_button.add_theme_color_override("font_hover_color", TEXT_COLOR.lightened(0.08))
	title_button.add_theme_color_override("font_pressed_color", TEXT_COLOR.darkened(0.08))
	title_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	title_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	title_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	title_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	turn_label.add_theme_font_size_override("font_size", turn_size)
	turn_label.add_theme_color_override("font_color", TEXT_COLOR)

	drawer_title.add_theme_font_size_override("font_size", drawer_title_size)
	drawer_title.add_theme_color_override("font_color", SLOT_TEXT_COLOR)
	_apply_rules_modal_theme(modal_title_size, modal_body_size, close_button_size, outer_margin)

	_layout_tile_strip(viewport_size, collapsed_y, expanded_y)
	_refresh_tile_buttons()


func _refresh_tile_buttons() -> void:
	for tile in tile_defs:
		var tile_id := String(tile["id"])
		var button := tile_buttons[tile_id] as Button
		var glyph := tile_glyphs[tile_id] as TokenGlyph
		var accent := Color(tile["accent"])
		var is_selected := tile_id == selected_tile_id
		var is_available := _tile_available_for_current_player(tile_id)
		var border_color := accent if is_selected else TILE_CARD_BORDER
		var background_color := accent.lightened(0.34) if is_selected else TILE_CARD_COLOR
		var ink_color := accent.darkened(0.72)
		if not is_available and not is_selected:
			background_color = background_color.darkened(0.04)
			border_color = TILE_CARD_BORDER.darkened(0.18)

		glyph.configure(tile_id, ink_color, 1.12, current_player_id == PLAYER_GUEST)
		button.disabled = not is_available and not is_selected
		button.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_available or is_selected else Color(1.0, 1.0, 1.0, 0.42)
		button.add_theme_stylebox_override("normal", _make_round_style(background_color, border_color, 3 if is_selected else 2))
		button.add_theme_stylebox_override("hover", _make_round_style(background_color.lightened(0.05), accent, 3))
		button.add_theme_stylebox_override("pressed", _make_round_style(background_color.darkened(0.04), accent, 3))


func _begin_tile_selection(tile_id: String, dragging := false) -> bool:
	if game_over:
		_log_turn("begin_tile_selection_blocked_game_over", {"tile_id": tile_id})
		return false
	if not _tile_available_for_current_player(tile_id):
		_log_turn("begin_tile_selection_blocked_unavailable", {
			"tile_id": tile_id,
			"owner_count": board_view.count_tiles_for_owner(tile_id, current_player_id),
		})
		_set_turn_text("%s has already placed %s. Each player only has one of each tile." % [
			_player_name(current_player_id),
			String(_tile_by_id(tile_id)["name"]),
		])
		return false

	moving_from_slot_id = ""
	selected_tile_id = tile_id
	_refresh_tile_buttons()
	_sync_drawer_copy()
	_set_turn_text("%s selected for %s. %s" % [
		String(_tile_by_id(tile_id)["name"]),
		_player_name(current_player_id),
		"Drag or tap a board point to place it." if dragging else "Tap a board point to place it.",
	])
	_set_interaction_text(_interaction_text_for_tile(tile_id))
	_log_turn("begin_tile_selection", {"tile_id": tile_id, "dragging": dragging})
	return true


func _begin_move_selection(slot_id: String, dragging := false) -> bool:
	var slot_tile_id := board_view.get_slot_tile_id(slot_id)
	var slot_owner_id := board_view.get_slot_owner_id(slot_id)
	if slot_tile_id.is_empty() or slot_owner_id != current_player_id:
		_log_turn("begin_move_selection_rejected", {
			"slot_id": slot_id,
			"slot_tile_id": slot_tile_id,
			"slot_owner_id": slot_owner_id,
		})
		return false

	moving_from_slot_id = slot_id
	selected_tile_id = slot_tile_id
	_refresh_tile_buttons()
	_sync_drawer_copy()
	_set_turn_text("%s is moving %s from %s. %s" % [
		_player_name(current_player_id),
		String(_tile_by_id(selected_tile_id)["name"]),
		board_view.get_slot_name(slot_id),
		"Drop it on a destination point." if dragging else "Tap a destination point.",
	])
	_set_interaction_text("Move action: you can move one of your own tiles. Non-flowers can move onto flowers and rust that spot.")
	_log_turn("begin_move_selection", {
		"slot_id": slot_id,
		"tile_id": selected_tile_id,
		"dragging": dragging,
	})
	return true


func _on_tile_pressed(tile_id: String) -> void:
	_log_turn("tile_button_pressed", {"tile_id": tile_id})
	_begin_tile_selection(tile_id)


func _on_board_slot_activated(slot_id: String) -> void:
	_log_turn("board_slot_activated", {
		"slot_id": slot_id,
		"slot_tile_id": board_view.get_slot_tile_id(slot_id),
		"slot_owner_id": board_view.get_slot_owner_id(slot_id),
	})
	if game_over:
		_log_turn("board_slot_activated_ignored_game_over", {"slot_id": slot_id})
		return
	if selected_tile_id.is_empty():
		if _begin_move_selection(slot_id):
			return
		_set_turn_text("%s selected. %s choose a tile from the drawer or tap one of your own tiles to move it." % [
			board_view.get_slot_name(slot_id),
			_player_name(current_player_id),
		])
		_set_interaction_text(_default_interaction_text())
		return

	var tile_name := String(_tile_by_id(selected_tile_id)["name"])
	var placement: Dictionary = {}
	if not moving_from_slot_id.is_empty():
		if moving_from_slot_id == slot_id:
			moving_from_slot_id = ""
			selected_tile_id = ""
			_refresh_tile_buttons()
			_sync_drawer_copy()
			_set_turn_text("Move cancelled. %s" % _turn_prompt())
			_set_interaction_text(_default_interaction_text())
			return
		placement = board_view.move_tile_for_owner(moving_from_slot_id, slot_id, current_player_id)
	else:
		placement = board_view.place_tile_for_owner(slot_id, selected_tile_id, current_player_id)
	if not bool(placement["ok"]):
		_log_turn("placement_rejected", {
			"slot_id": slot_id,
			"message": String(placement["message"]),
			"moving": not moving_from_slot_id.is_empty(),
		})
		_set_turn_text(String(placement["message"]))
		return
	_log_turn("placement_accepted", placement)

	var state_label: String = _state_label(String(placement["life_state"]))
	var bloom_suffix: String = " It blooms." if bool(placement["bloom"]) else ""
	var rust_suffix: String = " The spot rusts." if bool(placement["rusted"]) else ""
	var dead_tiles: Array = placement["dead_tiles"] if placement.has("dead_tiles") else []
	var dead_suffix: String = _dead_tiles_suffix(dead_tiles)
	var immediate_death_suffix := ""
	if bool(placement.get("died_this_turn", false)):
		immediate_death_suffix = " It withered immediately."

	if bool(placement["harmony_win"]):
		game_over = true
		_set_turn_text("Harmony circle complete. Host and Guest win together with %d blooming flowers." % [
			int(placement["host_blooms"]) + int(placement["guest_blooms"]),
		])
		_set_interaction_text("Harmony win: the full outer ring is blooming with flowers from both players.")
		return

	var action_text: String = "moved %s to %s" % [tile_name, board_view.get_slot_name(slot_id)] if not moving_from_slot_id.is_empty() else "placed %s on %s" % [tile_name, board_view.get_slot_name(slot_id)]
	moving_from_slot_id = ""
	selected_tile_id = ""
	_advance_turn()
	_refresh_tile_buttons()
	_sync_drawer_copy()
	_set_turn_text("%s %s. The line energy is %s.%s%s %s" % [
		_player_name(String(placement["owner_id"])),
		action_text,
		state_label,
		bloom_suffix + immediate_death_suffix,
		rust_suffix + dead_suffix,
		_turn_prompt(),
	])
	_set_interaction_text(_default_interaction_text())


func _on_tile_button_gui_input(event: InputEvent, tile_id: String) -> void:
	if game_over or rules_modal.visible:
		_log_turn("tile_button_gui_input_ignored", {
			"tile_id": tile_id,
			"game_over": game_over,
			"rules_visible": rules_modal.visible,
		})
		return
	if not _is_pointer_pressed(event):
		return
	if not _tile_available_for_current_player(tile_id):
		_log_turn("tile_button_gui_input_unavailable", {
			"tile_id": tile_id,
			"owner_count": board_view.count_tiles_for_owner(tile_id, current_player_id),
		})
		return

	var button := tile_buttons[tile_id] as Button
	if button == null:
		_log_turn("tile_button_gui_input_missing_button", {"tile_id": tile_id})
		return
	_stage_token_drag(
		"drawer",
		tile_id,
		"",
		button,
		_control_event_global_position(button, _event_position(event)),
		_event_pointer_kind(event),
		_event_pointer_index(event)
	)


func _on_board_slot_gui_input(slot_id: String, event: InputEvent, global_position: Vector2) -> void:
	if game_over or rules_modal.visible:
		_log_turn("board_slot_gui_input_ignored", {
			"slot_id": slot_id,
			"game_over": game_over,
			"rules_visible": rules_modal.visible,
		})
		return
	if not _is_pointer_pressed(event):
		return
	if board_view.get_slot_tile_id(slot_id).is_empty() or board_view.get_slot_owner_id(slot_id) != current_player_id:
		_log_turn("board_slot_gui_input_rejected", {
			"slot_id": slot_id,
			"slot_tile_id": board_view.get_slot_tile_id(slot_id),
			"slot_owner_id": board_view.get_slot_owner_id(slot_id),
		})
		return

	_stage_token_drag(
		"board",
		board_view.get_slot_tile_id(slot_id),
		slot_id,
		null,
		global_position,
		_event_pointer_kind(event),
		_event_pointer_index(event)
	)


func _stage_token_drag(source_kind: String, tile_id: String, from_slot_id: String, source_button: Button, pointer_position: Vector2, pointer_kind: String, pointer_index: int) -> void:
	if pointer_kind.is_empty():
		_log_turn("stage_token_drag_rejected_pointer_kind", {"source_kind": source_kind, "tile_id": tile_id})
		return
	if token_drag_pending or token_drag_active:
		_log_turn("stage_token_drag_rejected_busy", {
			"source_kind": source_kind,
			"tile_id": tile_id,
			"pending": token_drag_pending,
			"active": token_drag_active,
		})
		return

	token_drag_pending = true
	token_drag_pointer_kind = pointer_kind
	token_drag_pointer_index = pointer_index
	token_drag_source_kind = source_kind
	token_drag_tile_id = tile_id
	token_drag_from_slot_id = from_slot_id
	token_drag_source_button = source_button
	token_drag_start_position = pointer_position
	token_drag_pointer_position = pointer_position
	_log_turn("stage_token_drag", {
		"source_kind": source_kind,
		"tile_id": tile_id,
		"from_slot_id": from_slot_id,
		"pointer_kind": pointer_kind,
		"pointer_index": pointer_index,
	})


func _start_token_drag() -> void:
	if not token_drag_pending:
		return

	var started := false
	if token_drag_source_kind == "board":
		started = _begin_move_selection(token_drag_from_slot_id, true)
		board_view.cancel_slot_press(token_drag_from_slot_id)
	else:
		started = _begin_tile_selection(token_drag_tile_id, true)
		_cancel_button_press(token_drag_source_button)

	if not started:
		_log_turn("start_token_drag_failed", {
			"source_kind": token_drag_source_kind,
			"tile_id": token_drag_tile_id,
			"from_slot_id": token_drag_from_slot_id,
		})
		_reset_token_drag_state()
		return

	token_drag_pending = false
	token_drag_active = true
	_show_token_drag_preview(token_drag_tile_id)
	_update_token_drag()
	_log_turn("start_token_drag", {
		"source_kind": token_drag_source_kind,
		"tile_id": token_drag_tile_id,
		"from_slot_id": token_drag_from_slot_id,
	})


func _update_token_drag() -> void:
	if token_drag_preview != null and token_drag_preview.visible:
		var pointer_offset := Vector2(30.0, -32.0)
		if token_drag_pointer_kind == "touch":
			pointer_offset = Vector2(0.0, -token_drag_preview.size.y * 0.9)
		token_drag_preview.position = token_drag_pointer_position + pointer_offset - token_drag_preview.size * 0.5

	board_view.set_drag_hover_slot(board_view.slot_id_at_global_point(token_drag_pointer_position))


func _finish_token_drag() -> void:
	var target_slot_id := board_view.slot_id_at_global_point(token_drag_pointer_position)
	board_view.clear_drag_hover_slot()
	_log_turn("finish_token_drag", {
		"source_kind": token_drag_source_kind,
		"tile_id": token_drag_tile_id,
		"from_slot_id": token_drag_from_slot_id,
		"target_slot_id": target_slot_id,
	})
	if target_slot_id.is_empty():
		_set_turn_text(_drag_release_prompt())
		return
	_on_board_slot_activated(target_slot_id)


func _reset_token_drag_state() -> void:
	token_drag_pending = false
	token_drag_active = false
	token_drag_pointer_kind = ""
	token_drag_pointer_index = -1
	token_drag_source_kind = ""
	token_drag_tile_id = ""
	token_drag_from_slot_id = ""
	token_drag_source_button = null
	token_drag_start_position = Vector2.ZERO
	token_drag_pointer_position = Vector2.ZERO
	board_view.clear_drag_hover_slot()
	_hide_token_drag_preview()


func _show_token_drag_preview(tile_id: String) -> void:
	if token_drag_preview == null or token_drag_preview_glyph == null:
		return

	var tile := _tile_by_id(tile_id)
	var accent := Color(tile["accent"])
	var preview_size := clampf(minf(size.x, size.y) * 0.14, 88.0, 104.0)
	var inset := roundf(preview_size * 0.13)
	var preview_style := _make_round_style(TILE_CARD_COLOR, accent, 3)
	preview_style.shadow_color = Color(0.18, 0.12, 0.08, 0.2)
	preview_style.shadow_size = 10

	token_drag_preview.size = Vector2.ONE * preview_size
	token_drag_preview.pivot_offset = token_drag_preview.size * 0.5
	token_drag_preview.add_theme_stylebox_override("panel", preview_style)
	token_drag_preview_glyph.offset_left = inset
	token_drag_preview_glyph.offset_top = inset
	token_drag_preview_glyph.offset_right = -inset
	token_drag_preview_glyph.offset_bottom = -inset
	token_drag_preview_glyph.configure(tile_id, accent.darkened(0.72), 1.06, current_player_id == PLAYER_GUEST)
	token_drag_preview.visible = true


func _hide_token_drag_preview() -> void:
	if token_drag_preview != null:
		token_drag_preview.visible = false


func _drag_release_prompt() -> String:
	if selected_tile_id.is_empty():
		return _turn_prompt()
	if moving_from_slot_id.is_empty():
		return "%s selected for %s. Drag or tap a board point to place it." % [
			String(_tile_by_id(selected_tile_id)["name"]),
			_player_name(current_player_id),
		]
	return "%s is moving %s from %s. Drag or tap a destination point, or tap the source again to cancel." % [
		_player_name(current_player_id),
		String(_tile_by_id(selected_tile_id)["name"]),
		board_view.get_slot_name(moving_from_slot_id),
	]


func _cancel_button_press(button: Button) -> void:
	if button != null:
		button.set_pressed_no_signal(false)


func _control_event_global_position(control: Control, local_position: Vector2) -> Vector2:
	return control.get_global_transform_with_canvas() * local_position


func _event_pointer_kind(event: InputEvent) -> String:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return "mouse"
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch"
	return ""


func _event_pointer_index(event: InputEvent) -> int:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.index
	return 0


func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return event.position
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO


func _is_pointer_pressed(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	return false


func _event_matches_drag_pointer(event: InputEvent) -> bool:
	var pointer_kind := _event_pointer_kind(event)
	if pointer_kind.is_empty() or pointer_kind != token_drag_pointer_kind:
		return false
	if pointer_kind == "mouse":
		return not (event is InputEventMouseButton) or event.button_index == MOUSE_BUTTON_LEFT
	return _event_pointer_index(event) == token_drag_pointer_index


func _on_handle_area_gui_input(event: InputEvent) -> void:
	if _handle_drawer_drag_input(event):
		handle_area.accept_event()


func _on_drawer_sheet_gui_input(event: InputEvent) -> void:
	if not _should_capture_drawer_drag(event):
		return
	if _handle_drawer_drag_input(event):
		drawer_sheet.accept_event()


func _should_capture_drawer_drag(event: InputEvent) -> bool:
	if sheet_dragging:
		return true

	var drag_height := maxf(76.0, handle_area.size.y + 8.0)
	if event is InputEventScreenTouch:
		return event.position.y <= drag_height
	if event is InputEventScreenDrag:
		return event.position.y <= drag_height
	if event is InputEventMouseButton:
		return event.position.y <= drag_height
	if event is InputEventMouseMotion:
		return event.position.y <= drag_height
	return false


func _handle_drawer_drag_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_sheet_drag(event.position.y)
		else:
			_end_sheet_drag()
		return true

	if event is InputEventScreenDrag:
		_update_sheet_drag(event.position.y)
		return true

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_sheet_drag(event.position.y)
		else:
			_end_sheet_drag()
		return true

	if event is InputEventMouseMotion and sheet_dragging:
		_update_sheet_drag(event.position.y)
		return true

	return false


func _begin_sheet_drag(pointer_y: float) -> void:
	sheet_dragging = true
	sheet_drag_start_y = sheet_current_y
	sheet_pointer_start_y = pointer_y
	sheet_drag_delta = 0.0


func _update_sheet_drag(pointer_y: float) -> void:
	if not sheet_dragging:
		return

	var viewport_size := size
	var collapsed_y := viewport_size.y - peek_height
	var expanded_y := viewport_size.y - sheet_height
	sheet_drag_delta = pointer_y - sheet_pointer_start_y
	sheet_current_y = clampf(sheet_drag_start_y + sheet_drag_delta, expanded_y, collapsed_y)
	_layout_scene()


func _end_sheet_drag() -> void:
	if not sheet_dragging:
		return

	sheet_dragging = false
	var viewport_size := size
	var collapsed_y := viewport_size.y - peek_height
	var expanded_y := viewport_size.y - sheet_height

	if absf(sheet_drag_delta) < 10.0:
		sheet_state = SHEET_EXPANDED if sheet_state == SHEET_COLLAPSED else SHEET_COLLAPSED
	else:
		var midpoint := lerpf(expanded_y, collapsed_y, 0.5)
		sheet_state = SHEET_EXPANDED if sheet_current_y <= midpoint else SHEET_COLLAPSED

	sheet_target_y = _sheet_rest_y()
	_sync_drawer_copy()


func _sheet_rest_y() -> float:
	var viewport_size := size
	var collapsed_y := viewport_size.y - peek_height
	var expanded_y := viewport_size.y - sheet_height
	return expanded_y if sheet_state == SHEET_EXPANDED else collapsed_y


func _layout_tile_strip(viewport_size: Vector2, collapsed_y: float, expanded_y: float) -> void:
	var tile_button_size: float = clampf(viewport_size.x * 0.19, 126.0, 146.0)
	var glyph_inset: float = roundf(tile_button_size * 0.1)
	var reveal: float = _sheet_open_amount(collapsed_y, expanded_y)
	var tile_visible: bool = reveal > 0.02

	tile_scroll.visible = tile_visible
	tile_scroll.modulate = Color(1.0, 1.0, 1.0, clampf((reveal - 0.02) / 0.2, 0.0, 1.0))
	tile_row.position = Vector2.ZERO
	tile_row.custom_minimum_size = Vector2(0.0, tile_scroll.size.y)

	for tile_id in tile_buttons.keys():
		var button := tile_buttons[tile_id] as Button
		var glyph := tile_glyphs[tile_id] as TokenGlyph
		button.custom_minimum_size = Vector2.ONE * tile_button_size
		glyph.offset_left = glyph_inset
		glyph.offset_top = glyph_inset
		glyph.offset_right = -glyph_inset
		glyph.offset_bottom = -glyph_inset

func _sheet_open_amount(collapsed_y: float, expanded_y: float) -> float:
	var distance := collapsed_y - expanded_y
	if distance <= 0.001:
		return 1.0
	return clampf((collapsed_y - sheet_current_y) / distance, 0.0, 1.0)


func _sync_drawer_copy() -> void:
	var has_selection := not selected_tile_id.is_empty()
	drawer_title.visible = has_selection
	drawer_title.text = String(_tile_by_id(selected_tile_id)["name"]) if has_selection else ""


func _set_objective_text(text: String) -> void:
	objective_text_label.text = text


func _set_turn_text(text: String) -> void:
	turn_label.text = text


func _set_interaction_text(text: String) -> void:
	interaction_text_label.text = text


func _apply_rules_modal_theme(modal_title_size: int, modal_body_size: int, close_button_size: int, outer_margin: float) -> void:
	rules_backdrop.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	rules_backdrop.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	rules_backdrop.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	rules_backdrop.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	rules_backdrop.modulate = Color(0.0, 0.0, 0.0, 0.22)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = SHEET_COLOR
	panel_style.border_color = SHEET_BORDER
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 26
	panel_style.corner_radius_top_right = 26
	panel_style.corner_radius_bottom_right = 26
	panel_style.corner_radius_bottom_left = 26
	panel_style.shadow_color = Color(0.2, 0.12, 0.08, 0.18)
	panel_style.shadow_size = 18
	rules_panel.add_theme_stylebox_override("panel", panel_style)

	var max_panel_width := minf(size.x - outer_margin * 2.0, 560.0)
	rules_panel.custom_minimum_size = Vector2(max_panel_width, 0.0)
	var rules_padding := rules_panel.get_node("RulesPadding") as MarginContainer
	rules_padding.add_theme_constant_override("margin_left", 22)
	rules_padding.add_theme_constant_override("margin_top", 22)
	rules_padding.add_theme_constant_override("margin_right", 22)
	rules_padding.add_theme_constant_override("margin_bottom", 22)

	rules_title_label.add_theme_font_size_override("font_size", modal_title_size)
	rules_title_label.add_theme_color_override("font_color", TEXT_COLOR)
	objective_text_label.add_theme_font_size_override("font_size", modal_body_size)
	objective_text_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	interaction_text_label.add_theme_font_size_override("font_size", modal_body_size)
	interaction_text_label.add_theme_color_override("font_color", TEXT_COLOR)
	close_rules_button.add_theme_font_size_override("font_size", close_button_size)
	close_rules_button.add_theme_color_override("font_color", TEXT_COLOR)
	close_rules_button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	close_rules_button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	close_rules_button.add_theme_stylebox_override("normal", _make_round_style(TILE_CARD_COLOR, TILE_CARD_BORDER, 2))
	close_rules_button.add_theme_stylebox_override("hover", _make_round_style(TILE_CARD_COLOR.lightened(0.04), SHEET_BORDER, 2))
	close_rules_button.add_theme_stylebox_override("pressed", _make_round_style(TILE_CARD_COLOR.darkened(0.03), SHEET_BORDER, 2))


func _open_rules_modal() -> void:
	_reset_token_drag_state()
	rules_modal.visible = true
	rules_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	rules_backdrop.disabled = false


func _close_rules_modal() -> void:
	rules_backdrop.disabled = true
	rules_modal.visible = false
	rules_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_round_style(fill_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_right = 999
	style.corner_radius_bottom_left = 999
	return style


func _tile_by_id(tile_id: String) -> Dictionary:
	return tile_defs[int(tile_index_by_id[tile_id])]


func _tile_node_key(tile_id: String) -> String:
	var parts := tile_id.split("_")
	var result := ""
	for part in parts:
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result


func _advance_turn() -> void:
	var previous_player_id := current_player_id
	turn_count += 1
	current_player_id = PLAYER_GUEST if current_player_id == PLAYER_HOST else PLAYER_HOST
	_log_turn("advance_turn", {
		"previous_player_id": previous_player_id,
		"next_player_id": current_player_id,
		"turn_count": turn_count,
	})


func _turn_prompt() -> String:
	return "Turn %d. %s tends the garden." % [turn_count, _player_name(current_player_id)]


func _goal_text() -> String:
	return "On your turn, place a tile or move one of your own tiles. Each player only has one of each tile. Work together to make all 8 outer garden points bloom. If the full ring blooms with flowers from both players, both players win."


func _default_interaction_text() -> String:
	return "Flowers grow stronger from connected flowers and from Sun, Moon, and Dharma. Two adjacent Coin/Road/Beetle rust a flower, three kill it. Dead tiles return to their player at end of turn."


func _interaction_text_for_tile(tile_id: String) -> String:
	match tile_id:
		"lotus", "bell_flower", "lily":
			return "Flower tile: it grows stronger with connected flowers and with Sun, Moon, and Dharma. Two adjacent Coin, Road, or Beetle rust it; three kill it."
		"road":
			return "Road: a harsh structure tile. It can help shape links, but Sun, Moon, and Dharma weaken it, and too many harsh tiles around flowers will rust or kill them."
		"dharma":
			return "Dharma: a support tile. It strengthens flowers and nearby harmony, and it weakens harsh structure tiles like Coin, Road, and Beetle."
		"coin":
			return "Metal Coin: a harsh structure tile. It pressures flowers when clustered, but Sun, Moon, and Dharma can weaken its influence."
		"sun":
			return "Sun: strong flower support. It boosts flowers toward bloom and weakens Coin, Road, and Beetle."
		"moon":
			return "Moon: softer flower support. It helps flowers bloom and also weakens Coin, Road, and Beetle."
		"beetle":
			return "Beetle: a harsh structure tile. One nearby is manageable, two can rust a flower, and three can kill it."
		_:
			return _default_interaction_text()


func _tile_available_for_current_player(tile_id: String) -> bool:
	if moving_from_slot_id == "":
		return board_view.count_tiles_for_owner(tile_id, current_player_id) < 1
	return selected_tile_id == tile_id


func _dead_tiles_suffix(dead_tiles: Array) -> String:
	if dead_tiles.is_empty():
		return ""
	var names: Array = []
	for dead_tile in dead_tiles:
		if dead_tile is Dictionary and tile_index_by_id.has(String(dead_tile["tile_id"])):
			names.append(String(_tile_by_id(String(dead_tile["tile_id"]))["name"]))
	if names.is_empty():
		return " Dead tiles return to their player."
	return " %s returned to their player." % String(", ").join(names)


func _player_name(player_id: String) -> String:
	return "Host" if player_id == PLAYER_HOST else "Guest"


func _state_label(life_state: String) -> String:
	match life_state:
		"good":
			return "green"
		"dead":
			return "dead"
		_:
			return "rust"


func _log_turn(event_name: String, extra := {}) -> void:
	if not DEBUG_TURN_LOGS:
		return
	var payload := {
		"event": event_name,
		"current_player_id": current_player_id,
		"turn_count": turn_count,
		"selected_tile_id": selected_tile_id,
		"moving_from_slot_id": moving_from_slot_id,
		"sheet_state": sheet_state,
	}
	if extra is Dictionary:
		for key in extra.keys():
			payload[key] = extra[key]
	print("[pai-do][turn] %s" % JSON.stringify(payload))
