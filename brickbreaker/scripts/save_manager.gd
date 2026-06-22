extends Node

const SAVE_KEY := "zellis-brickbreaker-save"
const USER_PATH := "user://brickbreaker_save.json"
const MAX_LEVEL := 10

var high_score: int = 0
var max_unlocked_level: int = 1
var games_played: int = 0
var games_won: int = 0
var last_score: int = 0


func _ready() -> void:
    load_data()


func record_game_end(score: int, won: bool) -> bool:
    var new_best := score > high_score
    last_score = score
    games_played += 1
    if won:
        games_won += 1
    if new_best:
        high_score = score
    save_data()
    return new_best


func set_max_unlocked_level(level: int) -> void:
    var clamped := clampi(level, 1, MAX_LEVEL)
    if clamped <= max_unlocked_level:
        return
    max_unlocked_level = clamped
    save_data()


func load_data() -> void:
    var raw := _read_storage()
    if raw.is_empty():
        return
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var data: Dictionary = parsed
    high_score = int(data.get("high_score", 0))
    max_unlocked_level = clampi(int(data.get("max_unlocked_level", 1)), 1, MAX_LEVEL)
    games_played = int(data.get("games_played", 0))
    games_won = int(data.get("games_won", 0))
    last_score = int(data.get("last_score", 0))


func save_data() -> void:
    var payload := {
        "high_score": high_score,
        "max_unlocked_level": max_unlocked_level,
        "games_played": games_played,
        "games_won": games_won,
        "last_score": last_score,
    }
    _write_storage(JSON.stringify(payload))


func _read_storage() -> String:
    if OS.has_feature("web"):
        var js := "localStorage.getItem('%s') || ''" % SAVE_KEY
        if JavaScriptBridge.eval(js, true) != null:
            return str(JavaScriptBridge.eval(js, true))
        return ""
    var file := FileAccess.open(USER_PATH, FileAccess.READ)
    if file == null:
        return ""
    return file.get_as_text()


func _write_storage(payload: String) -> void:
    if OS.has_feature("web"):
        JavaScriptBridge.eval("localStorage.setItem('%s', %s);" % [SAVE_KEY, JSON.stringify(payload)])
        return
    var file := FileAccess.open(USER_PATH, FileAccess.WRITE)
    if file:
        file.store_string(payload)
