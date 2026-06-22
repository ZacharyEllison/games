extends StaticBody2D
## One pipe column: stretched sprite with a narrower hitbox than the art.

@export var column_height: float = 200.0
@export var column_width: float = 52.0
@export var collision_width: float = 34.0
@export var gap_edge_trim: float = 18.0
@export var is_top: bool = false

var texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
    add_to_group("obstacle_hazard")
    if texture != null:
        _apply_layout()


func configure(tex: Texture2D, height: float, width: float, top: bool) -> void:
    texture = tex
    column_height = height
    column_width = width
    is_top = top
    if is_node_ready():
        _apply_layout()


func _apply_layout() -> void:
    if texture == null:
        return

    sprite.texture = texture
    var tex_size: Vector2 = texture.get_size()
    if tex_size.x <= 0.0 or tex_size.y <= 0.0:
        return

    sprite.scale = Vector2(column_width / tex_size.x, column_height / tex_size.y)
    sprite.flip_v = is_top
    sprite.position = Vector2(0.0, column_height * 0.5)

    var hit_h: float = maxf(column_height - gap_edge_trim, 24.0)
    var rect := shape.shape as RectangleShape2D
    if rect == null:
        rect = RectangleShape2D.new()
        shape.shape = rect
    rect.size = Vector2(collision_width, hit_h)

    if is_top:
        shape.position = Vector2(0.0, hit_h * 0.5)
    else:
        shape.position = Vector2(0.0, gap_edge_trim + hit_h * 0.5)
