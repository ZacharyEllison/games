class_name BoardView
extends Control

signal slot_activated(slot_id: String)

const BOARD_ROTATION := PI / 4.0
const EDGE_THIRD := 1.0 / 3.0
const TOKEN_SCENE := preload("res://scenes/token_glyph.tscn")
const VECTOR_RING_SCENE := preload("res://scenes/vector_ring.tscn")

const BOARD_FRAME_COLOR := Color("e6d6c0")
const BOARD_FRAME_BORDER := Color("9d7458")
const BOARD_CIRCLE_COLOR := Color("9f8b5b")
const BOARD_LINE_COLOR := Color("8d6245")
const BOARD_HIGHLIGHT_COLOR := Color("c66f3d")
const SLOT_IDLE_FILL := Color("f8efe1")
const SLOT_CENTER_FILL := Color("e9d7c1")
const TILE_CARD_COLOR := Color("f4e8d8")
const TEXT_COLOR := Color("4a3427")
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

var board_plate: Panel
var board_canvas: Node2D
var board_circle: VectorRing
var slot_layer: Control

var line_nodes := {}
var slot_buttons := {}
var slot_glyphs := {}
var slot_positions := {}

var selected_slot_id := ""
var hover_slot_id := ""

var board_center := Vector2.ZERO
var board_span := 0.0
var board_circle_radius := 0.0
var slot_button_size := 84.0

var _built := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_slot_data()
	_build_scene()
	_apply_static_theme()
	resized.connect(_layout_board)
	mouse_exited.connect(_clear_hover_slot)
	_built = true
	_layout_board()
	_refresh_visuals()


func set_tile_defs(next_tile_defs: Array[Dictionary]) -> void:
	tile_defs.clear()
	tile_index_by_id.clear()

	for tile in next_tile_defs:
		if tile is Dictionary:
			tile_defs.append(tile.duplicate(true))

	for index in range(tile_defs.size()):
		tile_index_by_id[String(tile_defs[index]["id"])] = index

	if _built:
		_refresh_visuals()


func get_slot_name(slot_id: String) -> String:
	if not slot_index_by_id.has(slot_id):
		return slot_id
	return String(board_slots[int(slot_index_by_id[slot_id])]["name"])


func select_slot(slot_id: String) -> void:
	if not slot_index_by_id.has(slot_id):
		return
	selected_slot_id = slot_id
	_refresh_visuals()


func place_tile(slot_id: String, tile_id: String) -> void:
	if not slot_index_by_id.has(slot_id):
		return

	selected_slot_id = slot_id
	board_slots[int(slot_index_by_id[slot_id])]["placed_tile_id"] = tile_id
	_refresh_visuals()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hover_id := _find_slot_for_point(event.position)
		if hover_id != hover_slot_id:
			hover_slot_id = hover_id
			_refresh_visuals()
		return

	if event is InputEventScreenTouch and event.pressed:
		var touch_slot := _find_slot_for_point(event.position)
		if not touch_slot.is_empty():
			_emit_slot_activation(touch_slot)
			accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_slot := _find_slot_for_point(event.position)
		if not click_slot.is_empty():
			_emit_slot_activation(click_slot)
			accept_event()


func _build_slot_data() -> void:
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


func _build_scene() -> void:
	board_plate = Panel.new()
	board_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_plate)

	board_canvas = Node2D.new()
	add_child(board_canvas)

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
	add_child(slot_layer)

	for slot in board_slots:
		var slot_id := String(slot["id"])
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = String(slot["name"])
		button.pressed.connect(_on_slot_button_pressed.bind(slot_id))
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


func _apply_static_theme() -> void:
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


func _layout_board() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	board_span = minf(size.x * 0.94, size.y * 0.96)
	var square_side := board_span / sqrt(2.0)
	var square_half_side := square_side * 0.5
	var edge_offset := square_half_side * EDGE_THIRD
	board_circle_radius = sqrt(square_half_side * square_half_side + edge_offset * edge_offset)
	board_center = size * 0.5
	slot_button_size = clampf(square_side * 0.21, 58.0, 82.0)

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

	_refresh_visuals()


func _refresh_visuals() -> void:
	if not _built:
		return

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
		var fill_color := SLOT_CENTER_FILL if role == "center" else SLOT_IDLE_FILL
		var border_color := _slot_color(role)
		var border_width := 2

		if not placed_tile_id.is_empty() and tile_index_by_id.has(placed_tile_id):
			var tile := _tile_by_id(placed_tile_id)
			fill_color = TILE_CARD_COLOR
			border_color = Color(tile["accent"])
			glyph.visible = true
			glyph.configure(String(tile["id"]), Color(tile["accent"]).darkened(0.72), 0.92)
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


func _on_slot_button_pressed(slot_id: String) -> void:
	_emit_slot_activation(slot_id)


func _on_slot_mouse_entered(slot_id: String) -> void:
	hover_slot_id = slot_id
	_refresh_visuals()


func _on_slot_mouse_exited(slot_id: String) -> void:
	if hover_slot_id == slot_id:
		hover_slot_id = ""
		_refresh_visuals()


func _clear_hover_slot() -> void:
	if hover_slot_id.is_empty():
		return
	hover_slot_id = ""
	_refresh_visuals()


func _emit_slot_activation(slot_id: String) -> void:
	if not slot_index_by_id.has(slot_id):
		return
	selected_slot_id = slot_id
	_refresh_visuals()
	slot_activated.emit(slot_id)


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


func _slot_color(role: String) -> Color:
	return CENTER_SLOT_COLOR if role == "center" else EDGE_SLOT_COLOR


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


func _edge_key(edge: Array) -> String:
	return "%s:%s" % [String(edge[0]), String(edge[1])]


func _tile_by_id(tile_id: String) -> Dictionary:
	return tile_defs[int(tile_index_by_id[tile_id])]
