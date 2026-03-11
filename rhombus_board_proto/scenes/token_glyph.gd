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
	var radius := minf(size.x, size.y) * 0.34 * scale_bias
	if radius <= 0.0:
		return

	match glyph_id:
		"sunburst":
			_draw_sunburst(center, radius)
		"starwheel":
			_draw_starwheel(center, radius)
		"petal":
			_draw_petal(center, radius)
		"lotus":
			_draw_lotus(center, radius)
		"harp":
			_draw_harp(center, radius)
		"crest":
			_draw_crest(center, radius)
		"ring":
			_draw_ring_token(center, radius)
		"wheel":
			_draw_wheel(center, radius)
		"grain":
			_draw_grain(center, radius)
		"sail":
			_draw_sail(center, radius)
		"rosette":
			_draw_rosette(center, radius)
		"eclipse":
			_draw_eclipse(center, radius)


func _draw_sunburst(center: Vector2, radius: float) -> void:
	var line_width := maxf(2.0, radius * 0.16)
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var direction := Vector2.RIGHT.rotated(angle)
		draw_line(center + direction * radius * 0.42, center + direction * radius, ink_color, line_width, true)
	draw_circle(center, radius * 0.28, ink_color)


func _draw_starwheel(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0 - PI * 0.5
		var point_radius := radius if index % 2 == 0 else radius * 0.45
		points.append(center + Vector2.RIGHT.rotated(angle) * point_radius)
	draw_colored_polygon(points, ink_color)


func _draw_petal(center: Vector2, radius: float) -> void:
	for index in range(5):
		var angle := TAU * float(index) / 5.0 - PI * 0.5
		var petal_center := center + Vector2.RIGHT.rotated(angle) * radius * 0.48
		draw_circle(petal_center, radius * 0.34, ink_color)
	draw_circle(center, radius * 0.22, ink_color)


func _draw_lotus(center: Vector2, radius: float) -> void:
	for index in range(6):
		var angle := lerpf(-PI * 0.9, -PI * 0.1, float(index) / 5.0)
		draw_colored_polygon(_petal_polygon(center, radius * 0.9, angle, radius * 0.32), ink_color)
	for index in range(3):
		var angle := lerpf(-PI * 0.76, -PI * 0.24, float(index) / 2.0)
		draw_colored_polygon(_petal_polygon(center + Vector2(0.0, radius * 0.18), radius * 0.72, angle, radius * 0.24), ink_color)


func _draw_harp(center: Vector2, radius: float) -> void:
	var line_width := maxf(2.0, radius * 0.12)
	draw_arc(center + Vector2(0.0, radius * 0.15), radius * 0.72, PI * 0.1, PI * 0.9, 24, ink_color, line_width, true)
	draw_arc(center + Vector2(0.0, radius * 0.15), radius * 0.72, PI * 1.1, PI * 1.9, 24, ink_color, line_width, true)
	draw_line(center + Vector2(-radius * 0.36, -radius * 0.05), center + Vector2(-radius * 0.1, -radius * 0.62), ink_color, line_width, true)
	draw_line(center + Vector2(radius * 0.36, -radius * 0.05), center + Vector2(radius * 0.1, -radius * 0.62), ink_color, line_width, true)
	for index in range(4):
		var x := lerpf(-radius * 0.18, radius * 0.18, float(index) / 3.0)
		draw_line(center + Vector2(x, -radius * 0.58), center + Vector2(x, -radius * 0.1), ink_color, maxf(1.5, radius * 0.07), true)


func _draw_crest(center: Vector2, radius: float) -> void:
	var line_width := maxf(2.0, radius * 0.11)
	draw_arc(center + Vector2(0.0, -radius * 0.18), radius * 0.58, PI * 0.1, PI * 0.9, 20, ink_color, line_width, true)
	draw_arc(center + Vector2(0.0, radius * 0.16), radius * 0.54, PI * 1.1, PI * 1.9, 20, ink_color, line_width, true)
	draw_circle(center + Vector2(0.0, -radius * 0.78), radius * 0.12, ink_color)
	draw_line(center + Vector2(0.0, -radius * 0.66), center + Vector2(0.0, radius * 0.66), ink_color, line_width, true)


func _draw_ring_token(center: Vector2, radius: float) -> void:
	var line_width := maxf(2.0, radius * 0.12)
	draw_arc(center, radius * 0.9, 0.0, TAU, 40, ink_color, line_width, true)
	draw_rect(Rect2(center - Vector2.ONE * radius * 0.18, Vector2.ONE * radius * 0.36), ink_color)


func _draw_wheel(center: Vector2, radius: float) -> void:
	var line_width := maxf(2.0, radius * 0.11)
	draw_arc(center, radius * 0.88, 0.0, TAU, 40, ink_color, line_width, true)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var direction := Vector2.RIGHT.rotated(angle)
		draw_line(center - direction * radius * 0.15, center + direction * radius * 0.85, ink_color, line_width, true)
	draw_circle(center, radius * 0.14, ink_color)


func _draw_grain(center: Vector2, radius: float) -> void:
	var line_width := maxf(2.0, radius * 0.09)
	draw_arc(center + Vector2(-radius * 0.18, radius * 0.1), radius * 0.72, -PI * 0.2, PI * 0.52, 18, ink_color, line_width, true)
	draw_arc(center + Vector2(radius * 0.18, radius * 0.14), radius * 0.72, -PI * 0.22, PI * 0.5, 18, ink_color, line_width, true)
	for index in range(4):
		var y := lerpf(-radius * 0.46, radius * 0.24, float(index) / 3.0)
		draw_circle(center + Vector2(-radius * 0.12 + index * radius * 0.03, y), radius * 0.11, ink_color)
		draw_circle(center + Vector2(radius * 0.18 + index * radius * 0.03, y + radius * 0.06), radius * 0.11, ink_color)


func _draw_sail(center: Vector2, radius: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius * 0.82),
		center + Vector2(-radius * 0.58, radius * 0.38),
		center + Vector2(0.0, radius * 0.26),
	]), ink_color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius * 0.82),
		center + Vector2(radius * 0.58, radius * 0.38),
		center + Vector2(0.0, radius * 0.26),
	]), ink_color)
	draw_line(center + Vector2(-radius * 0.76, radius * 0.52), center + Vector2(radius * 0.76, radius * 0.52), ink_color, maxf(2.0, radius * 0.12), true)


func _draw_rosette(center: Vector2, radius: float) -> void:
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var petal_center := center + Vector2.RIGHT.rotated(angle) * radius * 0.48
		draw_circle(petal_center, radius * 0.26, ink_color)
	draw_circle(center, radius * 0.26, ink_color)


func _draw_eclipse(center: Vector2, radius: float) -> void:
	draw_colored_polygon(_leaf_polygon(center + Vector2(-radius * 0.1, 0.0), Vector2(radius * 0.4, radius * 0.82), -PI * 0.5), ink_color)
	draw_colored_polygon(_leaf_polygon(center + Vector2(radius * 0.1, 0.0), Vector2(radius * 0.4, radius * 0.82), PI * 0.5), ink_color)


func _petal_polygon(center: Vector2, radius: float, angle: float, width: float) -> PackedVector2Array:
	var tip := center + Vector2.RIGHT.rotated(angle) * radius
	var left := center + Vector2.RIGHT.rotated(angle + PI * 0.5) * width
	var right := center + Vector2.RIGHT.rotated(angle - PI * 0.5) * width
	return PackedVector2Array([center, left, tip, right])


func _leaf_polygon(center: Vector2, extents: Vector2, angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(8):
		var t := float(index) / 7.0
		var offset := Vector2(sin(t * PI) * extents.x, lerpf(-extents.y, extents.y, t))
		points.append(center + offset.rotated(angle))
	for index in range(8):
		var t := float(index) / 7.0
		var offset := Vector2(-sin((1.0 - t) * PI) * extents.x, lerpf(extents.y, -extents.y, t))
		points.append(center + offset.rotated(angle))
	return points
