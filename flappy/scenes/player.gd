extends Area2D

@export var rise_speed := 190.0
@export var fall_speed := 240.0
@export var rotate_speed_deg := 420.0
@export var up_angle_deg := -90.0
@export var down_angle_deg := 90.0
@export var bottom_margin := 18.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var screen_size := Vector2.ZERO
var center_x := 0.0
var waiting_for_press := true

func _ready() -> void:
	screen_size = get_viewport_rect().size
	center_x = screen_size.x * 0.5
	_reset_to_center()

func _physics_process(delta: float) -> void:
	# Keep movement centered horizontally.
	global_position.x = center_x
	var is_pressing := Input.is_action_pressed("press")

	if waiting_for_press:
		if is_pressing:
			waiting_for_press = false
		else:
			_set_flap_active(false)
			return

	var target_rotation = deg_to_rad(down_angle_deg)
	_set_flap_active(is_pressing)

	if is_pressing:
		target_rotation = deg_to_rad(up_angle_deg)
		global_position.y -= rise_speed * delta
	else:
		global_position.y += fall_speed * delta

	rotation = move_toward(rotation, target_rotation, deg_to_rad(rotate_speed_deg) * delta)

	if global_position.y >= screen_size.y - bottom_margin:
		_reset_to_center()

func _reset_to_center() -> void:
	waiting_for_press = true
	global_position = screen_size * 0.5
	rotation = 0.0
	_set_flap_active(false)

func _set_flap_active(active: bool) -> void:
	if active:
		if not animated_sprite.is_playing():
			animated_sprite.play("flap")
	else:
		animated_sprite.stop()
		animated_sprite.frame = 0
