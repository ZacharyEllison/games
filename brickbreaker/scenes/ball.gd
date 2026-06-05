extends CharacterBody2D

signal lost
signal nice_catch(pos: Vector2)

enum Kind { NORMAL, SPLITTER, EXPLODER }

@export var speed := 360.0
@export var radius := 12.0
@export var min_y_component := 0.35
@export var max_speed := 600.0

var kind := Kind.NORMAL
var direction := Vector2.UP
var active := false
var screen := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("balls")
	screen = get_viewport_rect().size
	_apply_kind_visual()

func set_kind(new_kind: int) -> void:
	kind = new_kind
	if is_inside_tree():
		_apply_kind_visual()

func _apply_kind_visual() -> void:
	match kind:
		Kind.SPLITTER:
			sprite.modulate = Color(0.45, 0.85, 1.0)
		Kind.EXPLODER:
			sprite.modulate = Color(1.0, 0.55, 0.2)
		_:
			sprite.modulate = Color.WHITE

func stick_to(pos: Vector2) -> void:
	active = false
	global_position = pos

func launch(dir: Vector2) -> void:
	direction = dir.normalized()
	_enforce_min_y()
	active = true
	_pop()

func _physics_process(delta: float) -> void:
	if not active:
		return
	var motion := direction * speed * delta
	var approach_dir := direction
	var collision := move_and_collide(motion)
	if collision:
		var normal := collision.get_normal()
		var collider := collision.get_collider()
		if collider:
			if collider.is_in_group("paddle"):
				_handle_paddle_hit(collider, normal, approach_dir)
			elif collider.is_in_group("walls"):
				direction = direction.bounce(normal).normalized()
			elif collider.has_method("on_hit"):
				direction = direction.bounce(normal).normalized()
				collider.on_hit()
				_on_brick_contact()
	_check_bottom_out()

func _handle_paddle_hit(collider: Node, _normal: Vector2, approach_dir: Vector2) -> void:
	var half_h: float = collider.half_height() if collider.has_method("half_height") else 11.0
	# Only when the ball has slipped under the paddle (not side or top hits).
	var paddle_bottom: float = collider.global_position.y + half_h
	var is_catch: bool = (
		approach_dir.y > 0.0
		and global_position.y >= paddle_bottom - radius * 0.5
	)
	if is_catch:
		direction.y = -abs(direction.y)
		direction = direction.normalized()
		speed = minf(speed * 1.5, max_speed)
		nice_catch.emit(global_position)
	else:
		var offset: float = (global_position.x - collider.global_position.x) / collider.half_width()
		direction.x = clamp(direction.x + offset * 0.65, -0.9, 0.9)
		direction.y = -abs(direction.y)
		direction = direction.normalized()

func _on_brick_contact() -> void:
	var game := get_tree().current_scene
	match kind:
		Kind.SPLITTER:
			if game and game.has_method("spawn_extra_balls"):
				game.spawn_extra_balls(global_position, 2)
			kind = Kind.NORMAL
			_apply_kind_visual()
		Kind.EXPLODER:
			if game and game.has_method("explode_at"):
				game.explode_at(global_position, 95.0)
			kind = Kind.NORMAL
			_apply_kind_visual()

func _check_bottom_out() -> void:
	screen = get_viewport_rect().size
	if global_position.y > screen.y + radius * 4.0:
		active = false
		lost.emit()
		return
	_enforce_min_y()

func _enforce_min_y() -> void:
	if abs(direction.y) < min_y_component:
		var sign_y := 1.0 if direction.y >= 0.0 else -1.0
		direction.y = min_y_component * sign_y
		direction = direction.normalized()

func _pop() -> void:
	var base := sprite.scale
	sprite.scale = base * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base, 0.2)
