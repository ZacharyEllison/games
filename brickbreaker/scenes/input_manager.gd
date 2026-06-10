extends Node2D

signal launch_held_ball
signal restart_game
signal pause_toggle

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_toggle.emit()

func _process(_delta: float) -> void:
	pass
