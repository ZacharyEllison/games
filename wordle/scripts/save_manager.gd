extends Node

const SAVE_KEY := "zellis-wordle-save"
const USER_PATH := "user://wordle_save.json"

var theme: String = "dark"
var hard_mode: bool = false
var total_points: int = 0
var games_played: int = 0
var games_won: int = 0
var current_streak: int = 0
var best_streak: int = 0
var guess_distribution: Array[int] = [0, 0, 0, 0, 0, 0]
var last_played_date: String = ""
var last_completed_date: String = ""
var hint_used_date: String = ""
var last_game_won: bool = false
var last_guess_count: int = 0
var today_completed: bool = false
var today_won: bool = false
var today_guess_count: int = 0

signal data_changed


func _ready() -> void:
    load_data()


func get_theme() -> String:
    return theme


func set_theme(value: String) -> void:
    theme = value if value == "light" else "dark"
    save_data()
    data_changed.emit()


func set_hard_mode(value: bool) -> void:
    hard_mode = value
    save_data()
    data_changed.emit()


func is_hint_used_today() -> bool:
    return hint_used_date == _today_key()


func mark_hint_used() -> void:
    hint_used_date = _today_key()
    save_data()
    data_changed.emit()


func record_game_start() -> void:
    var today := _today_key()
    if last_played_date != today:
        last_played_date = today
        save_data()


func record_win(guess_count: int) -> void:
    var today := _today_key()
    if today_completed and last_completed_date == today:
        return

    games_played += 1
    games_won += 1
    total_points += _points_for_guess_count(guess_count)
    if guess_count >= 1 and guess_count <= 6:
        guess_distribution[guess_count - 1] += 1

    _update_streak_on_win(today)
    last_completed_date = today
    last_played_date = today
    last_game_won = true
    last_guess_count = guess_count
    today_completed = true
    today_won = true
    today_guess_count = guess_count
    save_data()
    data_changed.emit()


func record_loss(guess_count: int) -> void:
    var today := _today_key()
    if today_completed and last_completed_date == today:
        return

    games_played += 1
    current_streak = 0
    last_completed_date = today
    last_played_date = today
    last_game_won = false
    last_guess_count = guess_count
    today_completed = true
    today_won = false
    today_guess_count = guess_count
    save_data()
    data_changed.emit()


func restore_today_state(completed: bool, won: bool, guess_count: int) -> void:
    today_completed = completed
    today_won = won
    today_guess_count = guess_count


func _update_streak_on_win(today: String) -> void:
    if last_completed_date.is_empty():
        current_streak = 1
    elif _is_yesterday(last_completed_date, today):
        current_streak += 1
    elif last_completed_date == today:
        pass
    else:
        current_streak = 1
    best_streak = maxi(best_streak, current_streak)


func points_for_guess_count(guess_count: int) -> int:
    return _points_for_guess_count(guess_count)


func _points_for_guess_count(guess_count: int) -> int:
    return clampi(7 - guess_count, 1, 6)


func _today_key() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


func _is_yesterday(previous: String, today: String) -> bool:
    var parts := previous.split("-")
    if parts.size() != 3:
        return false
    var dt := {
        "year": int(parts[0]),
        "month": int(parts[1]),
        "day": int(parts[2]),
        "hour": 12,
        "minute": 0,
        "second": 0,
    }
    var unix := Time.get_unix_time_from_datetime_dict(dt)
    unix += 86400
    var next := Time.get_datetime_dict_from_unix_time(unix)
    var next_key := "%04d-%02d-%02d" % [next.year, next.month, next.day]
    return next_key == today


func load_data() -> void:
    var raw := _read_storage()
    if raw.is_empty():
        return
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var data: Dictionary = parsed
    theme = str(data.get("theme", "dark"))
    hard_mode = bool(data.get("hard_mode", false))
    total_points = int(data.get("total_points", 0))
    games_played = int(data.get("games_played", 0))
    games_won = int(data.get("games_won", 0))
    current_streak = int(data.get("current_streak", 0))
    best_streak = int(data.get("best_streak", 0))
    last_played_date = str(data.get("last_played_date", ""))
    last_completed_date = str(data.get("last_completed_date", ""))
    hint_used_date = str(data.get("hint_used_date", ""))
    guess_distribution = _coerce_distribution(data.get("guess_distribution", []))
    last_game_won = bool(data.get("last_game_won", false))
    last_guess_count = int(data.get("last_guess_count", 0))
    var today := _today_key()
    today_completed = last_completed_date == today
    if today_completed:
        today_won = last_game_won
        today_guess_count = last_guess_count


func save_data() -> void:
    var payload := {
        "theme": theme,
        "hard_mode": hard_mode,
        "total_points": total_points,
        "games_played": games_played,
        "games_won": games_won,
        "current_streak": current_streak,
        "best_streak": best_streak,
        "guess_distribution": guess_distribution,
        "last_played_date": last_played_date,
        "last_completed_date": last_completed_date,
        "hint_used_date": hint_used_date,
        "last_game_won": last_game_won,
        "last_guess_count": last_guess_count,
    }
    _write_storage(JSON.stringify(payload))


func distribution_summary() -> String:
    var lines: PackedStringArray = []
    for i in range(guess_distribution.size()):
        lines.append("%d: %d" % [i + 1, guess_distribution[i]])
    return "\n".join(lines)


func _coerce_distribution(value: Variant) -> Array[int]:
    var result: Array[int] = [0, 0, 0, 0, 0, 0]
    if typeof(value) != TYPE_ARRAY:
        return result
    for i in range(mini(value.size(), 6)):
        result[i] = int(value[i])
    return result


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
