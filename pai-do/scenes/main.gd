@tool
extends Control

const SHEET_COLLAPSED := 0
const SHEET_EXPANDED := 1

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
@onready var title_label: Label = $HeaderMargin/HeaderBox/TitleLabel
@onready var status_label: Label = $HeaderMargin/HeaderBox/StatusLabel
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

var sheet_state := SHEET_COLLAPSED
var sheet_current_y := 0.0
var sheet_target_y := 0.0
var sheet_height := 360.0
var peek_height := 92.0
var sheet_dragging := false
var sheet_drag_start_y := 0.0
var sheet_pointer_start_y := 0.0
var sheet_drag_delta := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		Input.set_emulate_touch_from_mouse(true)
	_build_data()
	_cache_scene_nodes()
	_apply_static_theme()
	board_view.set_tile_defs(tile_defs)
	if not resized.is_connected(_layout_scene):
		resized.connect(_layout_scene)
	set_process(not Engine.is_editor_hint())
	_layout_scene()
	_sync_drawer_copy()
	_set_status("Select a tile from the drawer, then tap a board point.")


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


func _build_data() -> void:
	tile_defs = [
		{"id": "lotus", "name": "Lotus", "code": "LT", "accent": Color("b46f58")},
		{"id": "bell_flower", "name": "Bell Flower", "code": "BF", "accent": Color("9c7666")},
		{"id": "lily", "name": "Lily", "code": "LY", "accent": Color("b79b7d")},
		{"id": "temple", "name": "Temple", "code": "TP", "accent": Color("8c694f")},
		{"id": "coin", "name": "Metal Coin", "code": "MC", "accent": Color("b28743")},
		{"id": "road", "name": "Road", "code": "RD", "accent": Color("7c6d62")},
		{"id": "sun", "name": "Sun", "code": "SN", "accent": Color("c98b33")},
		{"id": "dhamma_wheel", "name": "Dhamma Wheel", "code": "DW", "accent": Color("9a5f2f")},
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
	title_label.text = "pai-do"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not board_view.slot_activated.is_connected(_on_board_slot_activated):
		board_view.slot_activated.connect(_on_board_slot_activated)
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
		if not button.pressed.is_connected(press_callable):
			button.pressed.connect(press_callable)
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
	var header_height := clampf(viewport_size.y * 0.11, 96.0, 144.0)
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
	var status_size := int(clampf(viewport_size.x * 0.034, 15.0, 20.0))
	var drawer_title_size := int(clampf(viewport_size.x * 0.04, 18.0, 22.0))

	eyebrow_label.add_theme_font_size_override("font_size", eyebrow_size)
	eyebrow_label.add_theme_color_override("font_color", BOARD_CIRCLE_COLOR)

	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.add_theme_color_override("font_color", TEXT_COLOR)

	status_label.add_theme_font_size_override("font_size", status_size)
	status_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)

	drawer_title.add_theme_font_size_override("font_size", drawer_title_size)
	drawer_title.add_theme_color_override("font_color", SLOT_TEXT_COLOR)

	_layout_tile_strip(viewport_size, collapsed_y, expanded_y)
	_refresh_tile_buttons()


func _refresh_tile_buttons() -> void:
	for tile in tile_defs:
		var tile_id := String(tile["id"])
		var button := tile_buttons[tile_id] as Button
		var glyph := tile_glyphs[tile_id] as TokenGlyph
		var accent := Color(tile["accent"])
		var is_selected := tile_id == selected_tile_id
		var border_color := accent if is_selected else TILE_CARD_BORDER
		var background_color := accent.lightened(0.34) if is_selected else TILE_CARD_COLOR
		var ink_color := accent.darkened(0.72)

		glyph.configure(tile_id, ink_color, 1.12)
		button.add_theme_stylebox_override("normal", _make_round_style(background_color, border_color, 3 if is_selected else 2))
		button.add_theme_stylebox_override("hover", _make_round_style(background_color.lightened(0.05), accent, 3))
		button.add_theme_stylebox_override("pressed", _make_round_style(background_color.darkened(0.04), accent, 3))


func _on_tile_pressed(tile_id: String) -> void:
	selected_tile_id = tile_id
	_refresh_tile_buttons()
	_sync_drawer_copy()
	_set_status("%s selected. Tap a board point to place it." % String(_tile_by_id(tile_id)["name"]))


func _on_board_slot_activated(slot_id: String) -> void:
	if selected_tile_id.is_empty():
		_set_status("%s selected. Choose a tile from the drawer." % board_view.get_slot_name(slot_id))
		return

	board_view.place_tile(slot_id, selected_tile_id)
	_set_status("Placed %s on %s." % [
		String(_tile_by_id(selected_tile_id)["name"]),
		board_view.get_slot_name(slot_id),
	])


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


func _set_status(text: String) -> void:
	status_label.text = text


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
