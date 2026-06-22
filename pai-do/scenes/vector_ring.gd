@tool
class_name VectorRing
extends Node2D

@export var radius := 64.0:
    set(value):
        radius = value
        queue_redraw()

@export var stroke_width := 4.0:
    set(value):
        stroke_width = value
        queue_redraw()

@export var stroke_color := Color("9f8b5b"):
    set(value):
        stroke_color = value
        queue_redraw()

@export_range(24, 256, 1) var point_count := 144:
    set(value):
        point_count = value
        queue_redraw()


func _draw() -> void:
    if radius <= 0.0 or stroke_width <= 0.0:
        return

    draw_arc(
        Vector2.ZERO,
        radius,
        0.0,
        TAU,
        point_count,
        stroke_color,
        stroke_width,
        true,
    )
