extends Control

const SHEET_COLLAPSED := 0
const SHEET_EXPANDED := 1
const BOARD_ROTATION := PI / 4.0
const EDGE_THIRD := 1.0 / 3.0
const TOKEN_SCENE := preload("res://scenes/token_glyph.tscn")
const VECTOR_RING_SCENE := preload("res://scenes/vector_ring.tscn")

const BACKGROUND_COLOR := Color("f7f0e4")
const BOARD_FRAME_COLOR := Color("e6d6c0")
const BOARD_FRAME_BORDER := Color("9d7458")
const BOARD_CIRCLE_COLOR := Color("9f8b5b")
const BOARD_LINE_COLOR := Color("8d6245")
const BOARD_HIGHLIGHT_COLOR := Color("c66f3d")
const SHEET_COLOR := Color("efe2cf")
const SHEET_BORDER := Color("b48766")
const SLOT_IDLE_FILL := Color("f8efe1")
const SLOT_CENTER_FILL := Color("e9d7c1")
const SLOT_TEXT_COLOR := Color("4f3728")
const SLOT_MUTED_TEXT := Color("876b55")
const TILE_CARD_COLOR := Color("f4e8d8")
const TILE_CARD_BORDER := Color("aa8162")
const TEXT_COLOR := Color("4a3427")
const MUTED_TEXT_COLOR := Color("8b725d")
const EDGE_SLOT_COLOR := Color("9d7a5b")
const CENTER_SLOT_COLOR := Color("c66f3d")

const BOARD_CONNECTIONS := [
	["left_top", "center_top_left"],
	["center_top_left", "center_top_right"],
	["center_top_right", "right_top"],
	["left_bottom", "center_bottom_left"],
	["center_bottom_left", "center_bottom_right"],
	["center_bottom_right", "right_bottom"],
	["top_left", "center_top_left"],
	["center_top_left", "center_bottom_left"],
	["center_bottom_left", "bottom_left"],
	["top_right", "center_top_right"],
	["center_top_right", "center_bottom_right"],
	["center_bottom_right", "bottom_right"],
]

var board_slots: Array[Dictionary] = []
var slot_index_by_id := {}
var tile_defs: Array[Dictionary] = []
var tile_index_by_id := {}

var background: ColorRect
var header_margin: MarginContainer
var header_box: VBoxContainer
var eyebrow_label: Label
var title_label: Label
var status_label: Label
var board_area: Control
var board_plate: Panel
var board_canvas: Node2D
var board_circle: VectorRing
var slot_layer: Control
var drawer_sheet: PanelContainer
var drawer_padding: MarginContainer
var drawer_content: VBoxContainer
var handle_area: Control
var handle_bar: ColorRect
var drawer_title: Label
var tile_scroll: ScrollContainer
var tile_row: HBoxContainer

var line_nodes := {}
var slot_buttons := {}
var slot_glyphs := {}
var tile_buttons := {}
var tile_glyphs := {}
var slot_positions := {}

var selected_tile_id := ""
var selected_slot_id := ""
var hover_slot_id := ""

var sheet_state := SHEET_COLLAPSED
var sheet_current_y := 0.0
var sheet_target_y := 0.0
var sheet_height := 360.0
var peek_height := 92.0
var sheet_dragging := false
var sheet_drag_start_y := 0.0
var sheet_pointer_start_y := 0.0
var sheet_drag_delta := 0.0

var board_center := Vector2.ZERO
var board_span := 0.0
var board_circle_radius := 0.0
var slot_button_size := 84.0


func _ready() -> void:
	Input.set_emulate_touch_from_mouse(true)
	_build_data()
	_build_scene()
	_build_board_nodes()
	_build_tile_buttons()
	_apply_static_theme()
	resized.connect(_layout_scene)
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
	board_slots = [
		{
			"id": "top_left",
			"name": "Top-left edge",
			"role": "edge",
			"norm": Vector2(-EDGE_THIRD, -1.0),
			"placed_tile_id": "",
		},
		{
			"id": "top_right",
			"name": "Top-right edge",
			"role": "edge",
			"norm": Vector2(EDGE_THIRD, -1.0),
			"placed_tile_id": "",
		},
		{
			"id": "right_top",
			"name": "Right-top edge",
			"role": "edge",
			"norm": Vector2(1.0, -EDGE_THIRD),
			"placed_tile_id": "",
		},
		{
			"id": "right_bottom",
			"name": "Right-bottom edge",
			"role": "edge",
			"norm": Vector2(1.0, EDGE_THIRD),
			"placed_tile_id": "",
		},
		{
			"id": "bottom_right",
			"name": "Bottom-right edge",
			"role": "edge",
			"norm": Vector2(EDGE_THIRD, 1.0),
			"placed_tile_id": "",
		},
		{
			"id": "bottom_left",
			"name": "Bottom-left edge",
			"role": "edge",
			"norm": Vector2(-EDGE_THIRD, 1.0),
			"placed_tile_id": "",
		},
		{
			"id": "left_bottom",
			"name": "Left-bottom edge",
			"role": "edge",
			"norm": Vector2(-1.0, EDGE_THIRD),
			"placed_tile_id": "",
		},
		{
			"id": "left_top",
			"name": "Left-top edge",
			"role": "edge",
			"norm": Vector2(-1.0, -EDGE_THIRD),
			"placed_tile_id": "",
		},
		{
			"id": "center_top_left",
			"name": "Upper-left crossing",
			"role": "center",
			"norm": Vector2(-EDGE_THIRD, -EDGE_THIRD),
			"placed_tile_id": "",
		},
		{
			"id": "center_top_right",
			"name": "Upper-right crossing",
			"role": "center",
			"norm": Vector2(EDGE_THIRD, -EDGE_THIRD),
			"placed_tile_id": "",
		},
		{
			"id": "center_bottom_right",
			"name": "Lower-right crossing",
			"role": "center",
			"norm": Vector2(EDGE_THIRD, EDGE_THIRD),
			"placed_tile_id": "",
		},
		{
			"id": "center_bottom_left",
			"name": "Lower-left crossing",
			"role": "center",
			"norm": Vector2(-EDGE_THIRD, EDGE_THIRD),
			"placed_tile_id": "",
		},
	]

	for index in range(board_slots.size()):
		slot_index_by_id[String(board_slots[index]["id"])] = index

	tile_defs = [
		{"id": "sunburst", "name": "Sunburst", "code": "SB", "accent": Color("c9923d")},
		{"id": "starwheel", "name": "Starwheel", "code": "SW", "accent": Color("b97a45")},
		{"id": "petal", "name": "Petal", "code": "PT", "accent": Color("b65f4e")},
		{"id": "lotus", "name": "Lotus", "code": "LT", "accent": Color("a96d58")},
		{"id": "harp", "name": "Harp", "code": "HP", "accent": Color("8d7a4e")},
		{"id": "crest", "name": "Crest", "code": "CR", "accent": Color("7f8a5f")},
		{"id": "ring", "name": "Ring", "code": "RG", "accent": Color("9b6b4f")},
		{"id": "wheel", "name": "Wheel", "code": "WH", "accent": Color("8c6b39")},
		{"id": "grain", "name": "Grain", "code": "GN", "accent": Color("b7a06a")},
		{"id": "sail", "name": "Sail", "code": "SL", "accent": Color("8d7867")},
		{"id": "rosette", "name": "Rosette", "code": "RS", "accent": Color("a85c48")},
		{"id": "eclipse", "name": "Eclipse", "code": "EC", "accent": Color("7d6857")},
	]

	for index in range(tile_defs.size()):
		tile_index_by_id[String(tile_defs[index]["id"])] = index


func _build_scene() -> void:
	background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	header_margin = MarginContainer.new()
	add_child(header_margin)

	header_box = VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 6)
	header_margin.add_child(header_box)

	eyebrow_label = Label.new()
	eyebrow_label.text = "PAI-DO PROTOTYPE"
	header_box.add_child(eyebrow_label)

	title_label = Label.new()
	title_label.text = "pai-do"
	header_box.add_child(title_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_box.add_child(status_label)

	board_area = Control.new()
	board_area.mouse_filter = Control.MOUSE_FILTER_STOP
	board_area.gui_input.connect(_on_board_area_gui_input)
	board_area.mouse_exited.connect(_clear_hover_slot)
	add_child(board_area)

	board_plate = Panel.new()
	board_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.add_child(board_plate)

	board_canvas = Node2D.new()
	board_area.add_child(board_canvas)

	board_circle = VECTOR_RING_SCENE.instantiate() as VectorRing
	board_circle.name = "BoardCircle"
	board_canvas.add_child(board_circle)

	for edge in BOARD_CONNECTIONS:
		var line := Line2D.new()
		line.default_color = BOARD_LINE_COLOR
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		board_canvas.add_child(line)
		line_nodes[_edge_key(edge)] = line

	slot_layer = Control.new()
	slot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.add_child(slot_layer)

	drawer_sheet = PanelContainer.new()
	drawer_sheet.clip_contents = true
	drawer_sheet.gui_input.connect(_on_drawer_sheet_gui_input)
	add_child(drawer_sheet)

	drawer_padding = MarginContainer.new()
	drawer_padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawer_sheet.add_child(drawer_padding)

	drawer_content = VBoxContainer.new()
	drawer_content.add_theme_constant_override("separation", 8)
	drawer_padding.add_child(drawer_content)

	handle_area = Control.new()
	handle_area.custom_minimum_size = Vector2(0.0, 58.0)
	handle_area.mouse_filter = Control.MOUSE_FILTER_STOP
	handle_area.gui_input.connect(_on_handle_area_gui_input)
	drawer_content.add_child(handle_area)

	var handle_box := VBoxContainer.new()
	handle_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	handle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle_box.add_theme_constant_override("separation", 8)
	handle_area.add_child(handle_box)

	var handle_center := CenterContainer.new()
	handle_center.custom_minimum_size = Vector2(0.0, 18.0)
	handle_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle_box.add_child(handle_center)

	handle_bar = ColorRect.new()
	handle_bar.custom_minimum_size = Vector2(70.0, 6.0)
	handle_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle_center.add_child(handle_bar)

	drawer_title = Label.new()
	drawer_title.visible = false
	drawer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drawer_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle_box.add_child(drawer_title)

	tile_scroll = ScrollContainer.new()
	tile_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_scroll.follow_focus = true
	drawer_content.add_child(tile_scroll)

	tile_row = HBoxContainer.new()
	tile_row.add_theme_constant_override("separation", 12)
	tile_scroll.add_child(tile_row)


func _build_board_nodes() -> void:
	for slot in board_slots:
		var slot_id := String(slot["id"])
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = String(slot["name"])
		button.pressed.connect(_on_slot_pressed.bind(slot_id))
		button.mouse_entered.connect(_on_slot_mouse_entered.bind(slot_id))
		button.mouse_exited.connect(_on_slot_mouse_exited.bind(slot_id))
		slot_layer.add_child(button)
		slot_buttons[slot_id] = button

		var glyph := TOKEN_SCENE.instantiate() as TokenGlyph
		glyph.name = "%sGlyph" % slot_id
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glyph.offset_left = 8.0
		glyph.offset_top = 8.0
		glyph.offset_right = -8.0
		glyph.offset_bottom = -8.0
		glyph.visible = false
		button.add_child(glyph)
		slot_glyphs[slot_id] = glyph


func _build_tile_buttons() -> void:
	for tile in tile_defs:
		var tile_id := String(tile["id"])
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = Vector2(104.0, 104.0)
		button.tooltip_text = String(tile["name"])
		button.text = ""
		button.pressed.connect(_on_tile_pressed.bind(tile_id))
		tile_row.add_child(button)
		tile_buttons[tile_id] = button

		var glyph := TOKEN_SCENE.instantiate() as TokenGlyph
		glyph.name = "%sToken" % tile_id
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glyph.offset_left = 16.0
		glyph.offset_top = 16.0
		glyph.offset_right = -16.0
		glyph.offset_bottom = -16.0
		glyph.configure(tile_id, TEXT_COLOR, 1.0)
		button.add_child(glyph)
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

	var board_style := StyleBoxFlat.new()
	board_style.bg_color = BOARD_FRAME_COLOR
	board_style.border_color = BOARD_FRAME_BORDER
	board_style.set_border_width_all(3)
	board_style.corner_radius_top_left = 38
	board_style.corner_radius_top_right = 38
	board_style.corner_radius_bottom_right = 38
	board_style.corner_radius_bottom_left = 38
	board_style.shadow_color = Color(0.45, 0.29, 0.16, 0.08)
	board_style.shadow_size = 8
	board_plate.add_theme_stylebox_override("panel", board_style)


func _layout_scene() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var outer_margin := clampf(viewport_size.x * 0.05, 18.0, 30.0)
	var header_height := clampf(viewport_size.y * 0.15, 128.0, 188.0)
	var header_top := clampf(viewport_size.y * 0.02, 16.0, 28.0)
	var board_gap := clampf(viewport_size.y * 0.018, 12.0, 22.0)

	sheet_height = clampf(viewport_size.y * 0.34, 300.0, 430.0)
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
	var board_height := maxf(220.0, board_bottom - board_top)
	board_area.position = Vector2(outer_margin, board_top)
	board_area.size = Vector2(viewport_size.x - outer_margin * 2.0, board_height)

	var title_size := int(clampf(viewport_size.x * 0.072, 30.0, 46.0))
	var eyebrow_size := int(clampf(viewport_size.x * 0.024, 12.0, 16.0))
	var status_size := int(clampf(viewport_size.x * 0.038, 16.0, 22.0))
	var drawer_title_size := int(clampf(viewport_size.x * 0.04, 18.0, 22.0))

	eyebrow_label.add_theme_font_size_override("font_size", eyebrow_size)
	eyebrow_label.add_theme_color_override("font_color", BOARD_CIRCLE_COLOR)

	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.add_theme_color_override("font_color", TEXT_COLOR)

	status_label.add_theme_font_size_override("font_size", status_size)
	status_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)

	drawer_title.add_theme_font_size_override("font_size", drawer_title_size)
	drawer_title.add_theme_color_override("font_color", SLOT_TEXT_COLOR)

	_layout_board()
	_refresh_tile_buttons()
	_refresh_board_visuals()


func _layout_board() -> void:
	if board_area.size.x <= 0.0 or board_area.size.y <= 0.0:
		return

	board_span = minf(board_area.size.x * 0.9, board_area.size.y * 0.9)
	var square_side := board_span / sqrt(2.0)
	var square_half_side := square_side * 0.5
	var edge_offset := square_half_side * EDGE_THIRD
	board_circle_radius = sqrt(square_half_side * square_half_side + edge_offset * edge_offset)
	board_center = board_area.size * 0.5 + Vector2(0.0, minf(10.0, board_area.size.y * 0.02))
	slot_button_size = clampf(square_side * 0.2, 56.0, 78.0)

	board_plate.size = Vector2(square_side, square_side)
	board_plate.position = board_center - board_plate.size * 0.5
	board_plate.pivot_offset = board_plate.size * 0.5
	board_plate.rotation = BOARD_ROTATION

	board_circle.position = board_center
	board_circle.radius = board_circle_radius
	board_circle.stroke_width = maxf(3.0, board_span * 0.012)
	board_circle.stroke_color = BOARD_CIRCLE_COLOR
	board_circle.point_count = 160

	slot_positions.clear()
	for slot in board_slots:
		var slot_id := String(slot["id"])
		var norm: Vector2 = slot["norm"]
		var local_point := norm * square_half_side
		var point: Vector2 = board_center + local_point.rotated(BOARD_ROTATION)
		slot_positions[slot_id] = point

	for edge in BOARD_CONNECTIONS:
		var line := line_nodes[_edge_key(edge)] as Line2D
		var start: Vector2 = slot_positions[String(edge[0])]
		var end: Vector2 = slot_positions[String(edge[1])]
		line.width = maxf(4.0, board_span * 0.011)
		line.points = PackedVector2Array([start, end])

	for slot in board_slots:
		var slot_id := String(slot["id"])
		var button := slot_buttons[slot_id] as Button
		button.size = Vector2.ONE * slot_button_size
		button.position = slot_positions[slot_id] - button.size * 0.5
		button.add_theme_font_size_override("font_size", int(slot_button_size * 0.28))


func _refresh_board_visuals() -> void:
	var focus_slot_id := hover_slot_id if not hover_slot_id.is_empty() else selected_slot_id

	for edge in BOARD_CONNECTIONS:
		var line := line_nodes[_edge_key(edge)] as Line2D
		var is_focused := focus_slot_id != "" and (String(edge[0]) == focus_slot_id or String(edge[1]) == focus_slot_id)
		line.default_color = BOARD_HIGHLIGHT_COLOR if is_focused else BOARD_LINE_COLOR
		line.width = maxf(4.0, board_span * (0.014 if is_focused else 0.011))

	for slot in board_slots:
		var slot_id := String(slot["id"])
		var placed_tile_id := String(slot["placed_tile_id"])
		var button := slot_buttons[slot_id] as Button
		var glyph := slot_glyphs[slot_id] as TokenGlyph
		var role := String(slot["role"])
		var role_color := _slot_color(role)
		var fill_color := SLOT_CENTER_FILL if role == "center" else SLOT_IDLE_FILL
		var border_color := role_color
		var border_width := 2
		var glyph_color := TEXT_COLOR

		if not placed_tile_id.is_empty():
			var tile := _tile_by_id(placed_tile_id)
			fill_color = TILE_CARD_COLOR
			border_color = Color(tile["accent"])
			glyph_color = Color(tile["accent"]).darkened(0.72)
			glyph.visible = true
			glyph.configure(String(tile["id"]), glyph_color, 0.92)
		else:
			glyph.visible = false

		if slot_id == hover_slot_id:
			border_color = border_color.lightened(0.16)
			border_width = 3
		if slot_id == selected_slot_id:
			border_color = BOARD_HIGHLIGHT_COLOR
			border_width = 4
		button.text = ""
		button.add_theme_stylebox_override("normal", _make_round_style(fill_color, border_color, border_width))
		button.add_theme_stylebox_override("hover", _make_round_style(fill_color.lightened(0.05), BOARD_HIGHLIGHT_COLOR, max(border_width, 3)))
		button.add_theme_stylebox_override("pressed", _make_round_style(fill_color.darkened(0.05), BOARD_HIGHLIGHT_COLOR, max(border_width, 3)))
		button.add_theme_stylebox_override("focus", _make_round_style(fill_color, BOARD_HIGHLIGHT_COLOR, max(border_width, 3)))


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

		glyph.configure(tile_id, ink_color, 1.0)
		button.add_theme_stylebox_override("normal", _make_round_style(background_color, border_color, 3 if is_selected else 2))
		button.add_theme_stylebox_override("hover", _make_round_style(background_color.lightened(0.05), accent, 3))
		button.add_theme_stylebox_override("pressed", _make_round_style(background_color.darkened(0.04), accent, 3))


func _on_tile_pressed(tile_id: String) -> void:
	selected_tile_id = tile_id
	_refresh_tile_buttons()
	_refresh_board_visuals()
	_sync_drawer_copy()
	_set_status("%s selected. Tap a board point to place it." % String(_tile_by_id(tile_id)["name"]))


func _on_slot_pressed(slot_id: String) -> void:
	_activate_slot(slot_id)


func _activate_slot(slot_id: String) -> void:
	selected_slot_id = slot_id
	if selected_tile_id.is_empty():
		_refresh_board_visuals()
		_set_status("%s selected. Choose a tile from the drawer." % String(_slot_by_id(slot_id)["name"]))
		return

	board_slots[int(slot_index_by_id[slot_id])]["placed_tile_id"] = selected_tile_id
	_refresh_board_visuals()
	_set_status("Placed %s on %s." % [
		String(_tile_by_id(selected_tile_id)["name"]),
		String(_slot_by_id(slot_id)["name"]),
	])


func _on_slot_mouse_entered(slot_id: String) -> void:
	hover_slot_id = slot_id
	_refresh_board_visuals()


func _on_slot_mouse_exited(slot_id: String) -> void:
	if hover_slot_id == slot_id:
		hover_slot_id = ""
		_refresh_board_visuals()


func _clear_hover_slot() -> void:
	if hover_slot_id.is_empty():
		return
	hover_slot_id = ""
	_refresh_board_visuals()


func _on_board_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hover_id := _find_slot_for_point(event.position)
		if hover_id != hover_slot_id:
			hover_slot_id = hover_id
			_refresh_board_visuals()
		return

	if event is InputEventScreenTouch and event.pressed:
		var touch_slot := _find_slot_for_point(event.position)
		if not touch_slot.is_empty():
			_activate_slot(touch_slot)
			board_area.accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_slot := _find_slot_for_point(event.position)
		if not click_slot.is_empty():
			_activate_slot(click_slot)
			board_area.accept_event()


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


func _find_slot_for_point(point: Vector2) -> String:
	if slot_positions.is_empty():
		return ""

	var nearest_slot_id := ""
	var nearest_slot_distance := INF
	for slot_id in slot_positions.keys():
		var slot_point: Vector2 = slot_positions[String(slot_id)]
		var distance := point.distance_to(slot_point)
		if distance < nearest_slot_distance:
			nearest_slot_distance = distance
			nearest_slot_id = String(slot_id)

	var direct_threshold := clampf(slot_button_size * 0.7, 48.0, 74.0)
	if nearest_slot_distance <= direct_threshold:
		return nearest_slot_id

	var line_threshold := clampf(board_span * 0.052, 20.0, 34.0)
	var snap_threshold := clampf(board_span * 0.22, 86.0, 132.0)
	var nearest_line_distance := INF
	for edge in BOARD_CONNECTIONS:
		var start: Vector2 = slot_positions[String(edge[0])]
		var end: Vector2 = slot_positions[String(edge[1])]
		nearest_line_distance = minf(nearest_line_distance, _distance_to_segment(point, start, end))

	if nearest_line_distance <= line_threshold and nearest_slot_distance <= snap_threshold:
		return nearest_slot_id

	return ""


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)

	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	var projection := start + segment * t
	return point.distance_to(projection)


func _sheet_rest_y() -> float:
	var viewport_size := size
	var collapsed_y := viewport_size.y - peek_height
	var expanded_y := viewport_size.y - sheet_height
	return expanded_y if sheet_state == SHEET_EXPANDED else collapsed_y


func _sync_drawer_copy() -> void:
	var has_selection := not selected_tile_id.is_empty()
	drawer_title.visible = has_selection
	drawer_title.text = String(_tile_by_id(selected_tile_id)["name"]) if has_selection else ""


func _set_status(text: String) -> void:
	status_label.text = text


func _slot_color(role: String) -> Color:
	match role:
		"center":
			return CENTER_SLOT_COLOR
		_:
			return EDGE_SLOT_COLOR


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


func _make_card_style(fill_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0.45, 0.29, 0.16, 0.08)
	style.shadow_size = 3
	return style


func _edge_key(edge: Array) -> String:
	return "%s:%s" % [String(edge[0]), String(edge[1])]


func _slot_by_id(slot_id: String) -> Dictionary:
	return board_slots[int(slot_index_by_id[slot_id])]


func _tile_by_id(tile_id: String) -> Dictionary:
	return tile_defs[int(tile_index_by_id[tile_id])]
