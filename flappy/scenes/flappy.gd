extends CharacterBody2D

signal died(reason: String)

@export var active_gravity: bool = false
@export var gravity: float = 520.0
@export var jump_strength: float = 340.0
@export var max_fall_speed: float = 520.0
@export var rotate_speed_deg: float = 480.0
@export var up_angle_deg: float = -25.0
@export var down_angle_deg: float = 65.0
@export var flap_squash_scale: Vector2 = Vector2(0.55, 1.55)
@export var flap_squash_duration: float = 0.32
@export var flap_squash_overshoot: Vector2 = Vector2(1.12, 0.9)

@onready var visual: Node2D = $Visual
@onready var fish_sprite: Sprite2D = $Visual/fish_orange

var _start_position: Vector2 = Vector2.ZERO
var _is_dead: bool = false
var _base_modulate: Color = Color.WHITE
var _base_visual_scale: Vector2 = Vector2.ONE
var _squash_tween: Tween


func _ready() -> void:
    add_to_group("player")
    _start_position = global_position
    _base_modulate = fish_sprite.modulate
    _base_visual_scale = visual.scale


func _physics_process(delta: float) -> void:
    if not active_gravity or _is_dead:
        return

    velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
    move_and_slide()

    var collision_count: int = get_slide_collision_count()
    if collision_count > 0:
        _die(_death_reason_from_collision(collision_count))
        return

    _update_rotation(delta)


func _input(event: InputEvent) -> void:
    if _is_dead or not active_gravity:
        return
    if event is InputEventScreenTouch and event.pressed:
        _flap()
    elif event.is_action_pressed("press"):
        _flap()


func flap() -> void:
    if _is_dead:
        return
    active_gravity = true
    velocity.y = -jump_strength
    _play_flap_squash()


func _flap() -> void:
    flap()


func activate_flappy() -> void:
    flap()


func reset_to(pos: Vector2) -> void:
    _kill_squash_tween()
    _is_dead = false
    active_gravity = false
    velocity = Vector2.ZERO
    global_position = pos
    rotation = 0.0
    fish_sprite.modulate = _base_modulate
    visual.scale = _base_visual_scale


func reset() -> void:
    reset_to(_start_position)


func _play_flap_squash() -> void:
    _kill_squash_tween()
    visual.scale = Vector2(
        _base_visual_scale.x * flap_squash_scale.x,
        _base_visual_scale.y * flap_squash_scale.y,
    )
    var overshoot := Vector2(
        _base_visual_scale.x * flap_squash_overshoot.x,
        _base_visual_scale.y * flap_squash_overshoot.y,
    )
    _squash_tween = create_tween()
    _squash_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _squash_tween.tween_property(visual, "scale", overshoot, flap_squash_duration * 0.45)
    _squash_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _squash_tween.tween_property(visual, "scale", _base_visual_scale, flap_squash_duration * 0.55)


func _kill_squash_tween() -> void:
    if _squash_tween != null and _squash_tween.is_valid():
        _squash_tween.kill()
    _squash_tween = null


func _update_rotation(delta: float) -> void:
    var target_deg: float = down_angle_deg if velocity.y > 0.0 else up_angle_deg
    var target_rad: float = deg_to_rad(target_deg)
    rotation = move_toward(rotation, target_rad, deg_to_rad(rotate_speed_deg) * delta)


func _death_reason_from_collision(collision_count: int) -> String:
    for i in collision_count:
        var info: KinematicCollision2D = get_slide_collision(i)
        var collider_obj: Object = info.get_collider()
        if collider_obj == null:
            continue
        var collider_node: Node = collider_obj as Node
        if collider_node.is_in_group("boundary"):
            if collider_node.name.contains("Top"):
                return "ceiling"
            return "seabed"
        if collider_node.is_in_group("obstacle_hazard"):
            return "seaweed"
    return "obstacle"


func _die(reason: String) -> void:
    if _is_dead:
        return
    _is_dead = true
    active_gravity = false
    velocity = Vector2.ZERO
    fish_sprite.modulate = Color(1.0, 0.35, 0.35)
    died.emit(reason)


func death_message(reason: String) -> String:
    match reason:
        "ceiling":
            return "Hit the surface!"
        "seabed":
            return "Hit the seabed!"
        "seaweed":
            return "Hit the seaweed!"
        _:
            return "Game Over"
