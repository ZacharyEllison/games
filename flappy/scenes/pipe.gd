extends Node2D

@export var color := Color(0, 1, 0)
@export var width := 80
@export var height := 300
@export var speed := 200
@export var spawn_top := true

var rect: ColorRect

func _ready() -> void:
	rect = ColorRect.new()
	rect.color = color
	add_child(rect)
	rect.position = Vector2.ZERO
	rect.size = Vector2(width, height)

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x + width < 0:
		queue_free()
