class_name HitboxDebugDrawer
extends Node2D
## Draws collision outlines on top of the game (works in web exports).

@export var enabled: bool = true
@export var shape_color: Color = Color(0.15, 1.0, 0.4, 0.9)
@export var line_width: float = 2.0


func _ready() -> void:
    z_index = 4096
    set_process(enabled)


func _process(_delta: float) -> void:
    if enabled:
        queue_redraw()


func _draw() -> void:
    if not enabled:
        return
    var root: Node = get_tree().current_scene
    if root != null:
        _draw_node(root)


func _draw_node(node: Node) -> void:
    if node is CollisionShape2D:
        _draw_collision_shape(node as CollisionShape2D)
    for child in node.get_children():
        _draw_node(child)


func _draw_collision_shape(col: CollisionShape2D) -> void:
    if col.disabled or col.shape == null:
        return

    var to_canvas: Transform2D = get_global_transform_with_canvas().affine_inverse()
    var shape_xform: Transform2D = to_canvas * col.global_transform
    draw_set_transform(shape_xform.origin, shape_xform.get_rotation(), shape_xform.get_scale())

    if col.shape is RectangleShape2D:
        var rect := col.shape as RectangleShape2D
        var half: Vector2 = rect.size * 0.5
        draw_rect(Rect2(-half, rect.size), shape_color, false, line_width)
    elif col.shape is CircleShape2D:
        var circle := col.shape as CircleShape2D
        draw_arc(Vector2.ZERO, circle.radius, 0.0, TAU, 48, shape_color, line_width)
    elif col.shape is CapsuleShape2D:
        var capsule := col.shape as CapsuleShape2D
        var r: float = capsule.radius
        var half_h: float = maxf(capsule.height * 0.5, 0.0)
        draw_rect(Rect2(Vector2(-r, -half_h - r), Vector2(r * 2.0, half_h * 2.0 + r * 2.0)), shape_color, false, line_width)

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
