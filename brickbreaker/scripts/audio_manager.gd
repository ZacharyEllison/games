extends Node

const HIT_SOUND := preload("res://audio/brick_click.wav")
const POOL_SIZE := 6

var _players: Array[AudioStreamPlayer] = []
var _next_index := 0
var _unlocked := false

func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.stream = HIT_SOUND
		player.volume_db = -4.0
		player.bus = &"Master"
		add_child(player)
		_players.append(player)

func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), false)
	# Warm up the audio pipeline with an inaudible play.
	var player := _players[0]
	var prev_db := player.volume_db
	player.volume_db = -80.0
	player.play()
	player.volume_db = prev_db

func play_hit(pitch_scale: float = 1.0) -> void:
	if not _unlocked:
		unlock()
	var player := _players[_next_index]
	_next_index = (_next_index + 1) % POOL_SIZE
	player.pitch_scale = pitch_scale
	player.stop()
	player.play()

func play_paddle_hit() -> void:
	if not _unlocked:
		unlock()
	var player := _players[_next_index]
	_next_index = (_next_index + 1) % POOL_SIZE
	player.volume_db = -12.0
	player.stop()
	player.play()
