@tool
class_name BoardView
extends Control

signal slot_activated(slot_id: String)
signal slot_gui_input(slot_id: String, event: InputEvent, global_position: Vector2)
const DEBUG_BOARD_LOGS := true

const BOARD_ROTATION := PI / 4.0
const EDGE_THIRD := 1.0 / 3.0
const PLAYER_HOST := "host"
const PLAYER_GUEST := "guest"

const BOARD_FRAME_COLOR := Color("e6d6c0")
const BOARD_FRAME_BORDER := Color("9d7458")
const BOARD_CIRCLE_COLOR := Color("9f8b5b")
const BOARD_LINE_COLOR := Color("8d6245")
const BOARD_HIGHLIGHT_COLOR := Color("c66f3d")
const LINE_GOOD_COLOR := Color("6f9d57")
const LINE_BAD_COLOR := Color("9a5f2f")
const LINE_DEAD_COLOR := Color("221915")
const SLOT_IDLE_FILL := Color("f8efe1")
const SLOT_CENTER_FILL := Color("e9d7c1")
const TILE_CARD_COLOR := Color("f4e8d8")
const TEXT_COLOR := Color("4a3427")
const EDGE_SLOT_COLOR := Color("9d7a5b")
const CENTER_SLOT_COLOR := Color("c66f3d")
const SLOT_GOOD_COLOR := Color("6f9d57")
const SLOT_BAD_COLOR := Color("9a5f2f")
const SLOT_DEAD_COLOR := Color("221915")
const FLOWER_IDS := {
	"lotus": true,
	"bell_flower": true,
	"lily": true,
}
const SUPPORT_IDS := {
	"sun": true,
	"moon": true,
	"dharma": true,
}
const HARSH_IDS := {
	"coin": true,
	"road": true,
	"beetle": true,
}
const EDGE_RING := [
	"top_left",
	"top_right",
	"right_top",
	"right_bottom",
	"bottom_right",
	"bottom_left",
	"left_bottom",
	"left_top",
]

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

@onready var board_plate: Panel = $BoardPlate
@onready var board_canvas: Node2D = $BoardCanvas
@onready var board_circle: VectorRing = $BoardCanvas/BoardCircle
@onready var slot_layer: Control = $SlotLayer

var line_nodes := {}
var slot_buttons := {}
var slot_glyphs := {}
var slot_positions := {}

var selected_slot_id := ""
var hover_slot_id := ""
var drag_hover_slot_id := ""

var board_center := Vector2.ZERO
var board_span := 0.0
var board_circle_radius := 0.0
var slot_button_size := 84.0

var _built := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_slot_data()
	_cache_scene_nodes()
	_apply_static_theme()
	if not resized.is_connected(_layout_board):
		resized.connect(_layout_board)
	if not mouse_exited.is_connected(_clear_hover_slot):
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


func slot_id_at_global_point(global_point: Vector2) -> String:
	if size.x <= 0.0 or size.y <= 0.0:
		return ""

	var local_point := get_global_transform_with_canvas().affine_inverse() * global_point
	var bounds_padding := clampf(slot_button_size * 0.8, 24.0, 60.0)
	if not Rect2(Vector2.ZERO, size).grow(bounds_padding).has_point(local_point):
		return ""
	return _find_slot_for_point(local_point)


func set_drag_hover_slot(slot_id: String) -> void:
	var next_slot_id := slot_id if slot_index_by_id.has(slot_id) else ""
	if drag_hover_slot_id == next_slot_id:
		return
	drag_hover_slot_id = next_slot_id
	_refresh_visuals()


func clear_drag_hover_slot() -> void:
	set_drag_hover_slot("")


func cancel_slot_press(slot_id: String) -> void:
	if not slot_buttons.has(slot_id):
		return
	var button := slot_buttons[slot_id] as Button
	if button != null:
		button.set_pressed_no_signal(false)


func place_tile(slot_id: String, tile_id: String, round_count: int = 1) -> void:
	place_tile_for_owner(slot_id, tile_id, PLAYER_HOST, round_count)


func place_tile_for_owner(slot_id: String, tile_id: String, owner_id: String, round_count: int = 1) -> Dictionary:
	return _resolve_tile_action("", slot_id, tile_id, owner_id, round_count)


func move_tile_for_owner(from_slot_id: String, to_slot_id: String, owner_id: String, round_count: int = 1) -> Dictionary:
	if not slot_index_by_id.has(from_slot_id):
		return {"ok": false, "message": "Unknown source point."}
	var source: Dictionary = board_slots[int(slot_index_by_id[from_slot_id])]
	var source_tile_id := String(source["placed_tile_id"])
	if source_tile_id.is_empty():
		return {"ok": false, "message": "There is no tile to move."}
	if String(source["owner_id"]) != owner_id:
		return {"ok": false, "message": "You can only move your own tiles."}
	return _resolve_tile_action(from_slot_id, to_slot_id, source_tile_id, owner_id, round_count)


func get_slot_tile_id(slot_id: String) -> String:
	if not slot_index_by_id.has(slot_id):
		return ""
	return String(board_slots[int(slot_index_by_id[slot_id])]["placed_tile_id"])


func get_slot_owner_id(slot_id: String) -> String:
	if not slot_index_by_id.has(slot_id):
		return ""
	return String(board_slots[int(slot_index_by_id[slot_id])]["owner_id"])


func count_tiles_for_owner(tile_id: String, owner_id: String) -> int:
	var total := 0
	for slot in board_slots:
		if String(slot["placed_tile_id"]) == tile_id and String(slot["owner_id"]) == owner_id:
			total += 1
	return total


func is_flower_tile(tile_id: String) -> bool:
	return FLOWER_IDS.has(tile_id)


func _resolve_tile_action(from_slot_id: String, slot_id: String, tile_id: String, owner_id: String, round_count: int) -> Dictionary:
	_log_board("resolve_tile_action_start", {
		"from_slot_id": from_slot_id,
		"slot_id": slot_id,
		"tile_id": tile_id,
		"owner_id": owner_id,
		"round_count": round_count,
	})
	if not slot_index_by_id.has(slot_id):
		_log_board("resolve_tile_action_unknown_slot", {"slot_id": slot_id})
		return {"ok": false, "message": "Unknown board point."}
	if not tile_index_by_id.has(tile_id):
		_log_board("resolve_tile_action_unknown_tile", {"tile_id": tile_id})
		return {"ok": false, "message": "Unknown tile."}
	if not from_slot_id.is_empty() and from_slot_id == slot_id:
		_log_board("resolve_tile_action_same_slot", {"slot_id": slot_id})
		return {"ok": false, "message": "Pick a different point to move the tile."}

	var slot: Dictionary = board_slots[int(slot_index_by_id[slot_id])]
	var existing_tile_id := String(slot["placed_tile_id"])
	var replaces_flower := false
	if not existing_tile_id.is_empty():
		if FLOWER_IDS.has(existing_tile_id):
			if FLOWER_IDS.has(tile_id):
				_log_board("resolve_tile_action_flower_on_flower", {
					"slot_id": slot_id,
					"existing_tile_id": existing_tile_id,
					"tile_id": tile_id,
				})
				return {"ok": false, "message": "Flowers cannot be placed on flowers."}
			replaces_flower = true
		else:
			_log_board("resolve_tile_action_occupied", {
				"slot_id": slot_id,
				"existing_tile_id": existing_tile_id,
			})
			return {"ok": false, "message": "%s is already occupied." % String(slot["name"])}

	if not from_slot_id.is_empty():
		var source_index := int(slot_index_by_id[from_slot_id])
		var source: Dictionary = board_slots[source_index]
		source["placed_tile_id"] = ""
		source["owner_id"] = ""
		source["entered_round"] = 0
		source["vitality"] = 0.0
		source["life_state"] = "empty"
		source["bloom"] = false
		board_slots[source_index] = source

	selected_slot_id = slot_id
	slot["placed_tile_id"] = tile_id
	slot["owner_id"] = owner_id
	slot["entered_round"] = round_count if FLOWER_IDS.has(tile_id) else 0
	slot["rusted"] = bool(slot.get("rusted", false)) or replaces_flower
	board_slots[int(slot_index_by_id[slot_id])] = slot
	_evaluate_board_state(round_count)
	var resolved_slot: Dictionary = board_slots[int(slot_index_by_id[slot_id])]
	var resolved_vitality := float(resolved_slot["vitality"])
	var resolved_life_state := String(resolved_slot["life_state"])
	var resolved_bloom := bool(resolved_slot["bloom"])
	var resolved_support := _support_value(resolved_slot)
	var resolved_harmony := _harmony_bonus(resolved_slot)
	var resolved_pressure := _distance_pressure(resolved_slot, owner_id)
	var dead_tiles: Array = _collect_dead_tiles()
	var died_this_turn := false
	for dead_tile in dead_tiles:
		if dead_tile is Dictionary and String(dead_tile["slot_id"]) == slot_id and String(dead_tile["tile_id"]) == tile_id:
			died_this_turn = true
			break
	if dead_tiles.size() > 0:
		_evaluate_board_state(round_count)
	_refresh_visuals()
	slot = board_slots[int(slot_index_by_id[slot_id])]

	var result: Dictionary = {
		"ok": true,
		"round_count": round_count,
		"from_slot_id": from_slot_id,
		"slot_id": slot_id,
		"tile_id": tile_id,
		"owner_id": owner_id,
		"replaced_tile_id": existing_tile_id,
		"rusted": bool(slot["rusted"]),
		"dead_tiles": dead_tiles,
		"died_this_turn": died_this_turn,
		"life_state": resolved_life_state,
		"bloom": resolved_bloom,
		"vitality": resolved_vitality,
		"support_value": resolved_support,
		"harmony_bonus": resolved_harmony,
		"distance_pressure": resolved_pressure,
		"final_life_state": String(slot["life_state"]),
		"harmony_win": _has_harmony_circle(),
		"host_blooms": _count_blooming_flowers(PLAYER_HOST),
		"guest_blooms": _count_blooming_flowers(PLAYER_GUEST),
	}
	_log_board("resolve_tile_action_success", result)
	return result


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hover_id := _find_slot_for_point(event.position)
		if hover_id != hover_slot_id:
			hover_slot_id = hover_id
			_refresh_visuals()
		return

	if event is InputEventScreenTouch and event.pressed:
		if not _find_direct_slot_for_point(event.position).is_empty():
			return
		var touch_slot := _find_slot_for_point(event.position)
		if not touch_slot.is_empty():
			_emit_slot_activation(touch_slot)
			accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _find_direct_slot_for_point(event.position).is_empty():
			return
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
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "top_right",
			"name": "Top-right edge",
			"role": "edge",
			"norm": Vector2(EDGE_THIRD, -1.0),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "right_top",
			"name": "Right-top edge",
			"role": "edge",
			"norm": Vector2(1.0, -EDGE_THIRD),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "right_bottom",
			"name": "Right-bottom edge",
			"role": "edge",
			"norm": Vector2(1.0, EDGE_THIRD),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "bottom_right",
			"name": "Bottom-right edge",
			"role": "edge",
			"norm": Vector2(EDGE_THIRD, 1.0),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "bottom_left",
			"name": "Bottom-left edge",
			"role": "edge",
			"norm": Vector2(-EDGE_THIRD, 1.0),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "left_bottom",
			"name": "Left-bottom edge",
			"role": "edge",
			"norm": Vector2(-1.0, EDGE_THIRD),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "left_top",
			"name": "Left-top edge",
			"role": "edge",
			"norm": Vector2(-1.0, -EDGE_THIRD),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "center_top_left",
			"name": "Upper-left crossing",
			"role": "center",
			"norm": Vector2(-EDGE_THIRD, -EDGE_THIRD),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "center_top_right",
			"name": "Upper-right crossing",
			"role": "center",
			"norm": Vector2(EDGE_THIRD, -EDGE_THIRD),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "center_bottom_right",
			"name": "Lower-right crossing",
			"role": "center",
			"norm": Vector2(EDGE_THIRD, EDGE_THIRD),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
		{
			"id": "center_bottom_left",
			"name": "Lower-left crossing",
			"role": "center",
			"norm": Vector2(-EDGE_THIRD, EDGE_THIRD),
			"placed_tile_id": "",
			"owner_id": "",
			"vitality": 0.0,
			"life_state": "empty",
			"bloom": false,
			"rusted": false,
		},
	]

	for index in range(board_slots.size()):
		var slot: Dictionary = board_slots[index]
		slot["entered_round"] = 0
		board_slots[index] = slot
		slot_index_by_id[String(slot["id"])] = index


func _cache_scene_nodes() -> void:
	line_nodes.clear()
	slot_buttons.clear()
	slot_glyphs.clear()

	for edge in BOARD_CONNECTIONS:
		var line_name := "Line_%s" % _edge_key(edge).replace(":", "_")
		var line := board_canvas.get_node(line_name) as Line2D
		line.default_color = BOARD_LINE_COLOR
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line_nodes[_edge_key(edge)] = line

	for slot in board_slots:
		var slot_id := String(slot["id"])
		var button_name := "%sButton" % _slot_node_key(slot_id)
		var glyph_name := "%sGlyph" % _slot_node_key(slot_id)
		var button := slot_layer.get_node(button_name) as Button
		var glyph := button.get_node(glyph_name) as TokenGlyph
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = String(slot["name"])
		var press_callable := _on_slot_button_pressed.bind(slot_id)
		var input_callable := _on_slot_button_gui_input.bind(slot_id)
		var enter_callable := _on_slot_mouse_entered.bind(slot_id)
		var exit_callable := _on_slot_mouse_exited.bind(slot_id)
		if not button.pressed.is_connected(press_callable):
			button.pressed.connect(press_callable)
		if not button.gui_input.is_connected(input_callable):
			button.gui_input.connect(input_callable)
		if not button.mouse_entered.is_connected(enter_callable):
			button.mouse_entered.connect(enter_callable)
		if not button.mouse_exited.is_connected(exit_callable):
			button.mouse_exited.connect(exit_callable)
		slot_buttons[slot_id] = button
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

	var focus_slot_id := drag_hover_slot_id
	if focus_slot_id.is_empty():
		focus_slot_id = hover_slot_id if not hover_slot_id.is_empty() else selected_slot_id

	for edge in BOARD_CONNECTIONS:
		var line := line_nodes[_edge_key(edge)] as Line2D
		var is_focused := focus_slot_id != "" and (String(edge[0]) == focus_slot_id or String(edge[1]) == focus_slot_id)
		line.default_color = BOARD_HIGHLIGHT_COLOR if is_focused else _connection_color(String(edge[0]), String(edge[1]))
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
			border_color = _life_color(String(slot["life_state"]))
			glyph.visible = true
			glyph.configure(
				String(tile["id"]),
				Color(tile["accent"]).darkened(0.72),
				0.92,
				String(slot["owner_id"]) == PLAYER_GUEST
			)
		else:
			glyph.visible = false
			if bool(slot.get("rusted", false)):
				border_color = SLOT_BAD_COLOR

		if slot_id == hover_slot_id:
			border_color = border_color.lightened(0.16)
			border_width = 3
		if slot_id == drag_hover_slot_id:
			border_color = BOARD_HIGHLIGHT_COLOR
			border_width = max(border_width, 4)
		if slot_id == selected_slot_id:
			border_color = BOARD_HIGHLIGHT_COLOR
			border_width = 4

		button.text = ""
		button.add_theme_stylebox_override("normal", _make_round_style(fill_color, border_color, border_width))
		button.add_theme_stylebox_override("hover", _make_round_style(fill_color.lightened(0.05), BOARD_HIGHLIGHT_COLOR, max(border_width, 3)))
		button.add_theme_stylebox_override("pressed", _make_round_style(fill_color.darkened(0.05), BOARD_HIGHLIGHT_COLOR, max(border_width, 3)))
		button.add_theme_stylebox_override("focus", _make_round_style(fill_color, BOARD_HIGHLIGHT_COLOR, max(border_width, 3)))


func _on_slot_button_pressed(slot_id: String) -> void:
	_log_board("slot_button_pressed", {
		"slot_id": slot_id,
		"slot_tile_id": get_slot_tile_id(slot_id),
		"slot_owner_id": get_slot_owner_id(slot_id),
	})
	_emit_slot_activation(slot_id)


func _on_slot_button_gui_input(event: InputEvent, slot_id: String) -> void:
	var button := slot_buttons[slot_id] as Button
	var local_position := _event_position(event)
	var global_position := local_position
	if button != null:
		global_position = button.get_global_transform_with_canvas() * local_position
	slot_gui_input.emit(slot_id, event, global_position)


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
	_log_board("emit_slot_activation", {
		"slot_id": slot_id,
		"slot_tile_id": get_slot_tile_id(slot_id),
		"slot_owner_id": get_slot_owner_id(slot_id),
	})
	slot_activated.emit(slot_id)


func _find_slot_for_point(point: Vector2) -> String:
	if slot_positions.is_empty():
		return ""

	var direct_slot_id := _find_direct_slot_for_point(point)
	if not direct_slot_id.is_empty():
		return direct_slot_id

	var nearest_slot_id := ""
	var nearest_slot_distance := INF
	for slot_id in slot_positions.keys():
		var slot_point: Vector2 = slot_positions[String(slot_id)]
		var distance := point.distance_to(slot_point)
		if distance < nearest_slot_distance:
			nearest_slot_distance = distance
			nearest_slot_id = String(slot_id)

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


func _find_direct_slot_for_point(point: Vector2) -> String:
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
	return ""


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)

	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	var projection := start + segment * t
	return point.distance_to(projection)


func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return event.position
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO


func _log_board(event_name: String, extra := {}) -> void:
	if not DEBUG_BOARD_LOGS:
		return
	var payload := {"event": event_name}
	if extra is Dictionary:
		for key in extra.keys():
			payload[key] = extra[key]
	print("[pai-do][board] %s" % JSON.stringify(payload))


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


func _slot_node_key(slot_id: String) -> String:
	var parts := slot_id.split("_")
	var result := ""
	for part in parts:
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result


func _tile_by_id(tile_id: String) -> Dictionary:
	return tile_defs[int(tile_index_by_id[tile_id])]


func _evaluate_board_state(round_count: int = 0) -> void:
	for index in range(board_slots.size()):
		var slot: Dictionary = board_slots[index]
		var tile_id := String(slot["placed_tile_id"])
		if tile_id.is_empty():
			slot["entered_round"] = 0
			slot["vitality"] = 0.0
			slot["life_state"] = "empty"
			slot["bloom"] = false
			board_slots[index] = slot
			continue

		var owner_id := String(slot["owner_id"])
		var vitality := _tile_base_power(tile_id)
		vitality += _support_value(slot)
		vitality += _harmony_bonus(slot)
		vitality -= _distance_pressure(slot, owner_id)
		if bool(slot.get("rusted", false)):
			vitality -= 0.65

		slot["vitality"] = vitality
		slot["life_state"] = _life_state(vitality)
		if FLOWER_IDS.has(tile_id):
			var harsh_neighbors: int = _count_neighbor_group(String(slot["id"]), HARSH_IDS)
			if harsh_neighbors > 2:
				slot["life_state"] = "dead"
			elif harsh_neighbors > 1:
				slot["life_state"] = "bad"
			if _flower_has_round_grace(slot, round_count) and String(slot["life_state"]) == "dead":
				slot["life_state"] = "bad"
		if bool(slot.get("rusted", false)) and String(slot["life_state"]) == "good":
			slot["life_state"] = "bad"
		slot["bloom"] = FLOWER_IDS.has(tile_id) and vitality >= 1.5
		board_slots[index] = slot


func _flower_has_round_grace(slot: Dictionary, round_count: int) -> bool:
	if round_count <= 0:
		return false
	var tile_id := String(slot["placed_tile_id"])
	if not FLOWER_IDS.has(tile_id):
		return false
	return int(slot.get("entered_round", 0)) == round_count


func _distance_pressure(slot: Dictionary, owner_id: String) -> float:
	var norm: Vector2 = slot["norm"]
	var distance_factor := 0.5
	if owner_id == PLAYER_HOST:
		distance_factor = inverse_lerp(-1.0, 1.0, norm.y)
	else:
		distance_factor = inverse_lerp(1.0, -1.0, norm.y)
	var role_penalty := 0.22 if String(slot["role"]) == "center" else 0.0
	return 0.3 + distance_factor * 1.65 + role_penalty


func _support_value(slot: Dictionary) -> float:
	var tile_id := String(slot["placed_tile_id"])
	var slot_id := String(slot["id"])
	var support_neighbors: int = _count_neighbor_group(slot_id, SUPPORT_IDS)
	var flower_neighbors: int = _count_neighbor_group(slot_id, FLOWER_IDS)
	var harsh_neighbors: int = _count_neighbor_group(slot_id, HARSH_IDS)
	var total := 0.0
	for neighbor in _neighbors_for_slot(String(slot["id"])):
		var neighbor_tile_id := String(neighbor["placed_tile_id"])
		if neighbor_tile_id.is_empty():
			continue
		if String(neighbor["owner_id"]) != String(slot["owner_id"]):
			total += 0.12
	match tile_id:
		"lotus", "bell_flower", "lily":
			total += float(flower_neighbors) * 0.42
			total += float(support_neighbors) * 0.58
			total -= float(harsh_neighbors) * 0.08
		"coin", "road", "beetle":
			total -= float(support_neighbors) * 0.52
			total += float(harsh_neighbors) * 0.08
		"sun", "moon", "dharma":
			total += float(flower_neighbors) * 0.2
			total += float(support_neighbors) * 0.12
		_:
			total += float(support_neighbors) * 0.12
	return total


func _harmony_bonus(slot: Dictionary) -> float:
	var has_host := false
	var has_guest := false
	for neighbor in _neighbors_for_slot(String(slot["id"])):
		if String(neighbor["placed_tile_id"]).is_empty():
			continue
		has_host = has_host or String(neighbor["owner_id"]) == PLAYER_HOST
		has_guest = has_guest or String(neighbor["owner_id"]) == PLAYER_GUEST
	if has_host and has_guest:
		return 0.55
	return 0.0


func _tile_base_power(tile_id: String) -> float:
	match tile_id:
		"lotus", "bell_flower", "lily":
			return 1.25
		"dharma":
			return 1.15
		"coin":
			return 1.0
		"road":
			return 0.95
		"sun":
			return 1.05
		"moon":
			return 0.92
		"beetle":
			return 0.88
		_:
			return 0.9


func _life_state(vitality: float) -> String:
	if vitality >= 1.45:
		return "good"
	if vitality >= 0.65:
		return "bad"
	return "dead"


func _life_color(life_state: String) -> Color:
	match life_state:
		"good":
			return SLOT_GOOD_COLOR
		"dead":
			return SLOT_DEAD_COLOR
		"bad":
			return SLOT_BAD_COLOR
		_:
			return BOARD_LINE_COLOR


func _connection_color(slot_a_id: String, slot_b_id: String) -> Color:
	var slot_a := _slot_by_id(slot_a_id)
	var slot_b := _slot_by_id(slot_b_id)
	var tile_a := String(slot_a["placed_tile_id"])
	var tile_b := String(slot_b["placed_tile_id"])
	if tile_a.is_empty() and tile_b.is_empty():
		return LINE_DEAD_COLOR

	var edge_energy := _edge_energy_from_slot(slot_a, slot_b_id) + _edge_energy_from_slot(slot_b, slot_a_id)
	if not tile_a.is_empty() and not tile_b.is_empty() and String(slot_a["owner_id"]) != String(slot_b["owner_id"]):
		edge_energy += 0.25
	if bool(slot_a["bloom"]) or bool(slot_b["bloom"]):
		edge_energy += 0.55
	if String(slot_a["life_state"]) == "dead" or String(slot_b["life_state"]) == "dead":
		edge_energy -= 1.1

	if edge_energy >= 1.25:
		return LINE_GOOD_COLOR
	if edge_energy >= 0.2:
		return LINE_BAD_COLOR
	return LINE_DEAD_COLOR


func _neighbors_for_slot(slot_id: String) -> Array[Dictionary]:
	var neighbors: Array[Dictionary] = []
	for edge in BOARD_CONNECTIONS:
		if String(edge[0]) == slot_id:
			neighbors.append(_slot_by_id(String(edge[1])))
		elif String(edge[1]) == slot_id:
			neighbors.append(_slot_by_id(String(edge[0])))
	return neighbors


func _slot_by_id(slot_id: String) -> Dictionary:
	return board_slots[int(slot_index_by_id[slot_id])]


func _count_neighbor_group(slot_id: String, group: Dictionary) -> int:
	var total := 0
	for neighbor in _neighbors_for_slot(slot_id):
		if group.has(String(neighbor["placed_tile_id"])):
			total += 1
	return total


func _collect_dead_tiles() -> Array:
	var dead_tiles: Array = []
	for index in range(board_slots.size()):
		var slot: Dictionary = board_slots[index]
		if String(slot["life_state"]) != "dead":
			continue
		var tile_id := String(slot["placed_tile_id"])
		if tile_id.is_empty():
			continue
		dead_tiles.append({
			"slot_id": String(slot["id"]),
			"tile_id": tile_id,
			"owner_id": String(slot["owner_id"]),
		})
		slot["placed_tile_id"] = ""
		slot["owner_id"] = ""
		slot["entered_round"] = 0
		slot["vitality"] = 0.0
		slot["life_state"] = "empty"
		slot["bloom"] = false
		board_slots[index] = slot
	return dead_tiles


func _edge_energy_from_slot(slot: Dictionary, opposite_slot_id: String) -> float:
	var tile_id := String(slot["placed_tile_id"])
	if tile_id.is_empty():
		return 0.0

	var total := _edge_token_energy(tile_id, bool(slot["bloom"]), String(slot["life_state"]))
	for neighbor in _neighbors_for_slot(String(slot["id"])):
		if String(neighbor["id"]) == opposite_slot_id:
			continue
		var neighbor_tile_id := String(neighbor["placed_tile_id"])
		if neighbor_tile_id.is_empty():
			continue
		total += _edge_token_energy(neighbor_tile_id, bool(neighbor["bloom"]), String(neighbor["life_state"])) * 0.35
	return total


func _edge_token_energy(tile_id: String, bloom: bool, life_state: String) -> float:
	var base := 0.0
	match tile_id:
		"road":
			base = 0.55
		"dharma":
			base = 0.62
		"sun":
			base = 0.52
		"coin":
			base = 0.3
		"moon":
			base = 0.18
		"beetle":
			base = -0.08
		"lotus", "bell_flower", "lily":
			base = 0.45 if bloom else 0.18
		_:
			base = 0.12

	if life_state == "good":
		base += 0.18
	elif life_state == "dead":
		base -= 0.42
	return base


func _count_blooming_flowers(owner_id: String) -> int:
	var total := 0
	for slot in board_slots:
		if String(slot["owner_id"]) == owner_id and bool(slot["bloom"]):
			total += 1
	return total


func _has_harmony_circle() -> bool:
	var has_host := false
	var has_guest := false
	for slot_id in EDGE_RING:
		var slot := _slot_by_id(slot_id)
		if not bool(slot["bloom"]):
			return false
		if not FLOWER_IDS.has(String(slot["placed_tile_id"])):
			return false
		has_host = has_host or String(slot["owner_id"]) == PLAYER_HOST
		has_guest = has_guest or String(slot["owner_id"]) == PLAYER_GUEST
	return has_host and has_guest
