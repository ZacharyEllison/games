extends Node2D

signal pause_requested
signal resume_requested
signal restart_requested
signal level_selected(level: int)

func request_pause(state: int) -> void:
	if state != 1 and state != 0:  # PLAYING or IDLE
		return
	pause_requested.emit()

func request_resume() -> void:
	resume_requested.emit()

func request_restart() -> void:
	restart_requested.emit()

func request_level_select(level: int) -> void:
	level_selected.emit(level)
