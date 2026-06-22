extends Node2D

signal obstacle_spawned(obstacle: Node2D)

@export var obstacle_scene: PackedScene
@export var min_interval: float = 2.0
@export var max_interval: float = 2.8
@export var gap_size: float = 228.0
@export var speed: float = 195.0
@export var min_gap_margin: float = 110.0
@export var min_spawn_spacing: float = 280.0
@export var first_spawn_delay: float = 1.1

var _spawning: bool = false
var _spawn_parent: Node = null


func _ready() -> void:
    _spawn_parent = get_parent()


func start() -> void:
    if _spawning:
        return
    _spawning = true
    var timer: SceneTreeTimer = get_tree().create_timer(first_spawn_delay)
    timer.timeout.connect(_on_first_spawn)


func stop() -> void:
    _spawning = false


func _on_first_spawn() -> void:
    if not _spawning:
        return
    if _can_spawn():
        _spawn_obstacle()
    _schedule_next()


func _schedule_next() -> void:
    if not _spawning:
        return
    var wait_time: float = randf_range(min_interval, max_interval)
    var timer: SceneTreeTimer = get_tree().create_timer(wait_time)
    timer.timeout.connect(_on_spawn_timer_timeout)


func _on_spawn_timer_timeout() -> void:
    if not _spawning:
        return
    if _can_spawn():
        _spawn_obstacle()
    _schedule_next()


func _can_spawn() -> bool:
    var viewport_width: float = get_viewport_rect().size.x
    var threshold: float = viewport_width - min_spawn_spacing
    for node in get_tree().get_nodes_in_group("obstacle"):
        if is_instance_valid(node) and node.global_position.x > threshold:
            return false
    return true


func _spawn_obstacle() -> void:
    if obstacle_scene == null or _spawn_parent == null:
        return

    var viewport_size: Vector2 = get_viewport_rect().size
    var available: float = viewport_size.y - gap_size
    if available <= min_gap_margin * 2.0:
        return

    var gap_center: float = randf_range(
        min_gap_margin + gap_size * 0.5,
        viewport_size.y - min_gap_margin - gap_size * 0.5,
    )

    var obstacle: Node2D = obstacle_scene.instantiate() as Node2D
    _spawn_parent.add_child(obstacle)
    obstacle.position = Vector2(viewport_size.x + 80.0, 0.0)

    if obstacle.has_method("configure"):
        obstacle.configure(gap_center, gap_size, speed)

    obstacle_spawned.emit(obstacle)
