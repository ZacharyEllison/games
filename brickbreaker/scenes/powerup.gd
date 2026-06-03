extends Area2D

signal collected(kind)

enum Kind { MULTIBALL, SPLITTER, EXPLODER }

const ICON_BASE := "res://art/kenney_brick-pack/PNG/Default/Special/"

@export var fall_speed := 145.0

var kind := Kind.MULTIBALL
var screen := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("powerups")
	screen = get_viewport_rect().size
	_apply_icon()
	body_entered.connect(_on_body_entered)

func set_kind(new_kind: int) -> void:
	kind = new_kind
	if is_inside_tree():
		_apply_icon()

func _apply_icon() -> void:
	match kind:
		Kind.SPLITTER:
			sprite.texture = load(ICON_BASE + "extra_box_exclamation.png")
			sprite.modulate = Color(0.45, 0.85, 1.0)
		Kind.EXPLODER:
			sprite.texture = load(ICON_BASE + "extra_crate_explosive.png")
			sprite.modulate = Color(1.0, 0.6, 0.25)
		_:
			sprite.texture = load(ICON_BASE + "extra_box_coin.png")
			sprite.modulate = Color.WHITE

func _process(delta: float) -> void:
	position.y += fall_speed * delta
	rotation += delta * 1.6
	if position.y > screen.y + 50.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("paddle"):
		collected.emit(kind)
		queue_free()
