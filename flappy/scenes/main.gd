extends Node2D

@onready var sky: ColorRect = $Sky

func _ready() -> void:
	_resize_sky()
	get_viewport().size_changed.connect(_resize_sky)

func _resize_sky() -> void:
	sky.position = Vector2.ZERO
	sky.size = get_viewport_rect().size
