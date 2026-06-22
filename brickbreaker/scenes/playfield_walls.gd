extends Node2D

const WALL_THICKNESS := 10.0
const WALL_LAYER := 8


func _ready() -> void:
    _rebuild_walls()


func _rebuild_walls() -> void:
    for child in get_children():
        child.queue_free()
    var size := get_viewport_rect().size
    _add_wall(
        "Left",
        Vector2(-WALL_THICKNESS * 0.5, size.y * 0.5),
        Vector2(WALL_THICKNESS, size.y + WALL_THICKNESS * 2.0),
    )
    _add_wall(
        "Right",
        Vector2(size.x + WALL_THICKNESS * 0.5, size.y * 0.5),
        Vector2(WALL_THICKNESS, size.y + WALL_THICKNESS * 2.0),
    )
    _add_wall(
        "Top",
        Vector2(size.x * 0.5, -WALL_THICKNESS * 0.5),
        Vector2(size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS),
    )


func _add_wall(wall_name: String, pos: Vector2, rect_size: Vector2) -> void:
    var wall := StaticBody2D.new()
    wall.name = wall_name
    wall.position = pos
    wall.collision_layer = WALL_LAYER
    wall.collision_mask = 0
    wall.add_to_group("walls")
    var shape_node := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = rect_size
    shape_node.shape = rect
    wall.add_child(shape_node)
    add_child(wall)
