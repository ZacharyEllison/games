extends StaticBody2D

signal destroyed(points, pos, tier)

var tier := 1

@onready var body: Sprite2D = $Body
@onready var eye_left: AnimatedSprite2D = $EyeLeft
@onready var eye_right: AnimatedSprite2D = $EyeRight
@onready var collision: CollisionShape2D = $CollisionShape2D
var _eye_left_home := Vector2.ZERO
var _eye_right_home := Vector2.ZERO

var _tex_blue: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Blue/brick_high_2.png")
var _tex_green: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Green/brick_high_2.png")
var _tex_yellow: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Yellow/brick_high_2.png")
var _tex_red: Texture2D = load("res://art/kenney_brick-pack/PNG/Default/Red/brick_high_2.png")

const ORANGE_MODULATE := Color(1.0, 0.58, 0.12)

func _ready() -> void:
	add_to_group("bricks")
	_eye_left_home = eye_left.position
	_eye_right_home = eye_right.position
	_start_eye(eye_left)
	_start_eye(eye_right)
	_refresh_texture()

func _start_eye(eye: AnimatedSprite2D) -> void:
	eye.speed_scale = randf_range(0.7, 1.4)
	eye.play(&"googly")
	eye.frame = randi() % eye.sprite_frames.get_frame_count(&"googly")

func setup(t: int) -> void:
	tier = t
	_refresh_texture()

func _refresh_texture() -> void:
	match tier:
		2:
			body.texture = _tex_green
			body.modulate = Color.WHITE
		3:
			body.texture = _tex_yellow
			body.modulate = Color.WHITE
		4:
			body.texture = _tex_yellow
			body.modulate = ORANGE_MODULATE
		5:
			body.texture = _tex_red
			body.modulate = Color.WHITE
		_:
			body.texture = _tex_blue
			body.modulate = Color.WHITE

func on_hit() -> void:
	AudioManager.play_hit(randf_range(0.65, 1.5))
	_jiggle()
	tier -= 1
	if tier <= 0:
		_destroy()
	else:
		_refresh_texture()

func shatter() -> void:
	AudioManager.play_hit(randf_range(0.65, 1.5))
	_jiggle()
	_destroy()

func _jiggle() -> void:
	var dir: float = [-1.0, 1.0].pick_random()
	body.scale = Vector2(1.45, 0.55)
	var scale_tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(body, "scale", Vector2.ONE, 0.45)
	var rot_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rot_tween.tween_property(body, "rotation", 0.0, 0.4).from(dir * randf_range(0.35, 0.6))
	_jiggle_eye(eye_left, _eye_left_home)
	_jiggle_eye(eye_right, _eye_right_home)

func _jiggle_eye(eye: AnimatedSprite2D, home: Vector2) -> void:
	var dir: float = [-1.0, 1.0].pick_random()
	var delay := randf_range(0.0, 0.09)
	eye.speed_scale = min(eye.speed_scale * 2.0, 8.0)
	var rot_tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	rot_tween.tween_interval(delay)
	rot_tween.tween_property(eye, "rotation", 0.0, 0.5).from(dir * randf_range(1.0, 2.2))
	var pos_tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pos_tween.tween_interval(delay)
	pos_tween.tween_property(eye, "position", home, 0.45).from(home + Vector2(randf_range(-5.0, 5.0), randf_range(-7.0, -3.0)))

func _destroy() -> void:
	collision.set_deferred("disabled", true)
	destroyed.emit(10 * tier, global_position, tier)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)
