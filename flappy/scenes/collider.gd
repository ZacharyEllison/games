extends Node2D

@export var top_margin: float = 8.0
@export var bottom_margin: float = 8.0
@export var wall_thickness: float = 20.0
@export var show_wall_sprites: bool = false

@onready var top_boundary: StaticBody2D = $TopBoundary
@onready var bottom_boundary: StaticBody2D = $BottomBoundary
@onready var top_shape: CollisionShape2D = $TopBoundary/CollisionShape2D
@onready var top_sprite: Sprite2D = $TopBoundary/Sprite2D
@onready var bottom_shape: CollisionShape2D = $BottomBoundary/CollisionShape2D
@onready var bottom_sprite: Sprite2D = $BottomBoundary/Sprite2D


func _ready() -> void:
    top_boundary.add_to_group("boundary")
    bottom_boundary.add_to_group("boundary")
    top_sprite.visible = show_wall_sprites
    bottom_sprite.visible = show_wall_sprites
    _layout()
    get_viewport().size_changed.connect(_layout)


func _layout() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var width: float = viewport_size.x

    var top_rect := top_shape.shape as RectangleShape2D
    if top_rect == null:
        top_rect = RectangleShape2D.new()
        top_shape.shape = top_rect
    top_rect.size = Vector2(width, wall_thickness)
    top_boundary.position = Vector2(width * 0.5, top_margin + wall_thickness * 0.5)

    var bottom_rect := bottom_shape.shape as RectangleShape2D
    if bottom_rect == null:
        bottom_rect = RectangleShape2D.new()
        bottom_shape.shape = bottom_rect
    bottom_rect.size = Vector2(width, wall_thickness)
    bottom_boundary.position = Vector2(
        width * 0.5,
        viewport_size.y - bottom_margin - wall_thickness * 0.5,
    )
