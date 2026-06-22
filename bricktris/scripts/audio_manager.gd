extends Node

var _place_player: AudioStreamPlayer
var _chime_player: AudioStreamPlayer


func _ready() -> void:
    _place_player = AudioStreamPlayer.new()
    _chime_player = AudioStreamPlayer.new()
    add_child(_place_player)
    add_child(_chime_player)

    var chime := load("res://audio/chime.mp3")
    if chime:
        _chime_player.stream = chime


func play_place() -> void:
    if _place_player.stream == null:
        _place_player.stream = _make_click()
    _place_player.pitch_scale = randf_range(0.9, 1.1)
    _place_player.play()


func play_chime() -> void:
    _chime_player.play()


# Generates a 12ms square-wave click at ~440 Hz when no asset is available.
func _make_click() -> AudioStreamWAV:
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_8_BITS
    wav.mix_rate = 22050
    var samples := PackedByteArray()
    for i in 265:
        samples.append(127 if (i % 50) < 25 else 0)
    wav.data = samples
    return wav
