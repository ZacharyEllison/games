extends StaticBody2D

signal destroyed(points, pos, tier)

var max_hits := 1
var hits := 0
var stages: Array = []
var _broken := false

@onready var body: Sprite2D = $Body
@onready var eye_left: AnimatedSprite2D = $EyeLeft
@onready var eye_right: AnimatedSprite2D = $EyeRight
@onready var collision: CollisionShape2D = $CollisionShape2D
var _eye_left_home := Vector2.ZERO
var _eye_right_home := Vector2.ZERO

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

func setup(hit_count: int, stage_data: Array) -> void:
	max_hits = max(1, hit_count)
	stages = stage_data
	hits = 0
	if is_inside_tree():
		_refresh_texture()

func _refresh_texture() -> void:
	if stages.is_empty():
		return
	var index := clampi(hits, 0, stages.size() - 1)
	var stage: Dictionary = stages[index]
	body.texture = stage.texture
	body.modulate = stage.get("modulate", Color.WHITE)

func on_hit() -> void:
	if _broken:
		return
	hits += 1
	AudioManager.play_hit(randf_range(0.65, 1.5))
	_jiggle()
	if hits >= max_hits:
		_break()
	else:
		_refresh_texture()

func shatter() -> void:
	if _broken:
		return
	AudioManager.play_hit(randf_range(0.65, 1.5))
	_jiggle()
	hits = max_hits
	_break()

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

func _break() -> void:
	if _broken:
		return
	_broken = true
	collision.set_deferred("disabled", true)
	destroyed.emit(max_hits * 10, global_position, max_hits)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)
