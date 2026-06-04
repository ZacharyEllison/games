extends CharacterBody2D

@export var key_speed := 620.0

var screen := Vector2.ZERO
var half_w := 64.0
var half_h := 11.0

@onready var shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("paddle")
	screen = get_viewport_rect().size
	half_w = shape.shape.size.x * 0.5
	half_h = shape.shape.size.y * 0.5

func half_width() -> float:
	return half_w

func half_height() -> float:
	return half_h

func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var target_x := global_position.x
	if axis != 0.0:
		target_x += axis * key_speed * delta
	else:
		target_x = get_viewport().get_mouse_position().x
	global_position.x = clamp(target_x, half_w, screen.x - half_w)
