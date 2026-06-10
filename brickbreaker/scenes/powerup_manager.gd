extends Node2D

const POWERUP := preload("res://scenes/powerup.tscn")
const POWERUP_CHANCE_BY_TIER := { 1: 0.033, 2: 0.165, 3: 0.33, 4: 0.40, 5: 0.45 }

signal powerup_dropped(powerup: Area2D)
signal on_collected(kind: int, pos: Vector2)

func should_drop(tier: int) -> bool:
	var chance: float = POWERUP_CHANCE_BY_TIER.get(tier, 0.03)
	return randf() < chance

func drop(pos: Vector2, tier: int) -> void:
	var powerup := POWERUP.instantiate()
	add_child(powerup)
	powerup.global_position = pos
	powerup.set_kind(_pick_kind(tier))
	powerup.collected.connect(func(kind): on_collected.emit(kind, pos))
	powerup_dropped.emit(powerup)

func _pick_kind(tier: int) -> int:
	if tier == 1:
		var roll := randf()
		if roll < 0.35:
			return 3
		roll -= 0.35
		if roll < 0.217:
			return 0
		roll -= 0.217
		if roll < 0.217:
			return 1
		return 2
	return randi() % 4

func clear_all() -> void:
	for child in get_children():
		if child is Area2D:
			child.queue_free()
