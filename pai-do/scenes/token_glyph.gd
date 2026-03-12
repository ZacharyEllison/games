@tool
class_name TokenGlyph
extends Control

@export var glyph_id := "":
	set(value):
		glyph_id = value
		queue_redraw()

@export var ink_color := Color("2f2118"):
	set(value):
		ink_color = value
		queue_redraw()

@export var scale_bias := 1.0:
	set(value):
		scale_bias = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(next_glyph_id: String, next_ink_color: Color, next_scale_bias := 1.0) -> void:
	glyph_id = next_glyph_id
	ink_color = next_ink_color
	scale_bias = next_scale_bias
	queue_redraw()


func _draw() -> void:
	if glyph_id.is_empty():
		return

	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.33 * scale_bias
	if radius <= 0.0:
		return

	match glyph_id:
		"lotus":
			_draw_lotus(center, radius)
		"bell_flower":
			_draw_bell_flower(center, radius)
		"lily":
			_draw_lily(center, radius)
		"temple":
			_draw_temple(center, radius)
		"coin":
			_draw_coin(center, radius)
		"road":
			_draw_road(center, radius)
		"sun":
			_draw_sun(center, radius)
		"dhamma_wheel":
			_draw_dhamma_wheel(center, radius)
		"moon":
			_draw_moon(center, radius)


func _draw_lotus(center: Vector2, radius: float) -> void:
	draw_colored_polygon(_petal_polygon(center + Vector2(0.0, radius * 0.06), radius * 0.92, -PI * 0.5, radius * 0.2), ink_color)
	draw_colored_polygon(_petal_polygon(center + Vector2(-radius * 0.24, radius * 0.16), radius * 0.74, -PI * 0.72, radius * 0.18), ink_color)
	draw_colored_polygon(_petal_polygon(center + Vector2(radius * 0.24, radius * 0.16), radius * 0.74, -PI * 0.28, radius * 0.18), ink_color)
	draw_colored_polygon(_petal_polygon(center + Vector2(-radius * 0.38, radius * 0.28), radius * 0.48, -PI * 0.8, radius * 0.14), ink_color)
	draw_colored_polygon(_petal_polygon(center + Vector2(radius * 0.38, radius * 0.28), radius * 0.48, -PI * 0.2, radius * 0.14), ink_color)
	draw_line(center + Vector2(-radius * 0.7, radius * 0.48), center + Vector2(radius * 0.7, radius * 0.48), ink_color, maxf(2.0, radius * 0.1), true)


func _draw_bell_flower(center: Vector2, radius: float) -> void:
	var stroke := maxf(2.0, radius * 0.1)
	draw_line(center + Vector2(0.0, -radius * 0.92), center + Vector2(0.0, -radius * 0.28), ink_color, stroke, true)
	draw_arc(center + Vector2(0.0, -radius * 0.98), radius * 0.18, 0.0, PI, 18, ink_color, stroke * 0.75, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-radius * 0.46, -radius * 0.18),
		center + Vector2(radius * 0.46, -radius * 0.18),
		center + Vector2(radius * 0.3, radius * 0.44),
		center + Vector2(0.0, radius * 0.68),
		center + Vector2(-radius * 0.3, radius * 0.44),
	]), ink_color)
	for x in [-0.26, 0.0, 0.26]:
		draw_line(center + Vector2(radius * x, radius * 0.34), center + Vector2(radius * x, radius * 0.64), ink_color, stroke * 0.75, true)


func _draw_lily(center: Vector2, radius: float) -> void:
	draw_colored_polygon(_petal_polygon(center + Vector2(0.0, radius * 0.1), radius * 0.98, -PI * 0.5, radius * 0.16), ink_color)
	draw_colored_polygon(_petal_polygon(center + Vector2(-radius * 0.18, radius * 0.22), radius * 0.8, -PI * 0.78, radius * 0.14), ink_color)
	draw_colored_polygon(_petal_polygon(center + Vector2(radius * 0.18, radius * 0.22), radius * 0.8, -PI * 0.22, radius * 0.14), ink_color)
	var stroke := maxf(2.0, radius * 0.08)
	draw_line(center + Vector2(-radius * 0.08, radius * 0.12), center + Vector2(-radius * 0.2, radius * 0.62), ink_color, stroke, true)
	draw_line(center + Vector2(0.0, radius * 0.06), center + Vector2(0.0, radius * 0.66), ink_color, stroke, true)
	draw_line(center + Vector2(radius * 0.08, radius * 0.12), center + Vector2(radius * 0.2, radius * 0.62), ink_color, stroke, true)


func _draw_temple(center: Vector2, radius: float) -> void:
	var stroke := maxf(2.0, radius * 0.1)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius * 0.82),
		center + Vector2(radius * 0.82, -radius * 0.28),
		center + Vector2(-radius * 0.82, -radius * 0.28),
	]), ink_color)
	draw_rect(Rect2(center + Vector2(-radius * 0.74, -radius * 0.18), Vector2(radius * 1.48, radius * 0.12)), ink_color)
	for x in [-0.42, -0.14, 0.14, 0.42]:
		draw_rect(Rect2(center + Vector2(radius * x - radius * 0.08, -radius * 0.06), Vector2(radius * 0.16, radius * 0.7)), ink_color)
	draw_rect(Rect2(center + Vector2(-radius * 0.86, radius * 0.66), Vector2(radius * 1.72, radius * 0.14)), ink_color)
	draw_line(center + Vector2(-radius * 0.9, radius * 0.8), center + Vector2(radius * 0.9, radius * 0.8), ink_color, stroke, true)


func _draw_coin(center: Vector2, radius: float) -> void:
	var stroke := maxf(2.0, radius * 0.11)
	draw_arc(center, radius * 0.84, 0.0, TAU, 48, ink_color, stroke, true)
	draw_arc(center, radius * 0.52, 0.0, TAU, 40, ink_color, stroke * 0.9, true)
	draw_rect(Rect2(center - Vector2.ONE * radius * 0.18, Vector2.ONE * radius * 0.36), ink_color)


func _draw_road(center: Vector2, radius: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-radius * 0.74, radius * 0.82),
		center + Vector2(-radius * 0.22, -radius * 0.82),
		center + Vector2(radius * 0.22, -radius * 0.82),
		center + Vector2(radius * 0.74, radius * 0.82),
	]), ink_color)

	var lane_color := Color.WHITE
	var lane_width := maxf(2.0, radius * 0.12)
	for offset in [-0.22, 0.22]:
		draw_line(center + Vector2(radius * offset, -radius * 0.28), center + Vector2(radius * offset * 2.4, radius * 0.74), lane_color, lane_width, true)


func _draw_sun(center: Vector2, radius: float) -> void:
	var stroke := maxf(2.0, radius * 0.11)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var direction := Vector2.RIGHT.rotated(angle)
		draw_line(center + direction * radius * 0.48, center + direction * radius * 0.9, ink_color, stroke, true)
	draw_arc(center, radius * 0.34, 0.0, TAU, 36, ink_color, stroke, true)


func _draw_dhamma_wheel(center: Vector2, radius: float) -> void:
	var stroke := maxf(2.0, radius * 0.1)
	draw_arc(center, radius * 0.84, 0.0, TAU, 48, ink_color, stroke, true)
	draw_arc(center, radius * 0.18, 0.0, TAU, 24, ink_color, stroke, true)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var direction := Vector2.RIGHT.rotated(angle)
		draw_line(center + direction * radius * 0.2, center + direction * radius * 0.78, ink_color, stroke, true)


func _draw_moon(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(-radius * 0.08, 0.0), radius * 0.74, ink_color)
	draw_circle(center + Vector2(radius * 0.28, -radius * 0.02), radius * 0.7, Color("f4e8d8"))


func _petal_polygon(center: Vector2, length_radius: float, angle: float, width: float) -> PackedVector2Array:
	var tip := center + Vector2.RIGHT.rotated(angle) * length_radius
	var left := center + Vector2.RIGHT.rotated(angle + PI * 0.5) * width
	var right := center + Vector2.RIGHT.rotated(angle - PI * 0.5) * width
	return PackedVector2Array([center, left, tip, right])
