extends Node2D

@export var speed: float = 200.0
@export var column_width: float = 52.0
@export var art_textures: Array[Texture2D] = []

@onready var top_column: StaticBody2D = $TopColumn
@onready var bottom_column: StaticBody2D = $BottomColumn

var gap_center_y: float = 360.0
var gap_size: float = 190.0


func _ready() -> void:
    add_to_group("obstacle")
    _apply_layout()


func configure(gap_y: float, gap: float, scroll_speed: float) -> void:
    gap_center_y = gap_y
    gap_size = gap
    speed = scroll_speed
    if is_node_ready():
        _apply_layout()


func _apply_layout() -> void:
    var tex: Texture2D = _pick_texture()
    if tex == null:
        return

    var viewport_h: float = get_viewport_rect().size.y
    var gap_half: float = gap_size * 0.5
    var gap_top: float = gap_center_y - gap_half
    var gap_bottom: float = gap_center_y + gap_half
    var top_h: float = maxf(gap_top, 40.0)
    var bottom_h: float = maxf(viewport_h - gap_bottom, 40.0)

    top_column.position = Vector2.ZERO
    bottom_column.position = Vector2(0.0, gap_bottom)

    if top_column.has_method("configure"):
        top_column.configure(tex, top_h, column_width, true)
    if bottom_column.has_method("configure"):
        bottom_column.configure(tex, bottom_h, column_width, false)


func _process(delta: float) -> void:
    position.x -= speed * delta
    if position.x < -120.0:
        queue_free()


func _pick_texture() -> Texture2D:
    if art_textures.is_empty():
        return null
    return art_textures[randi() % art_textures.size()]
