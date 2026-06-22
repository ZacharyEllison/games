extends Node

enum GameState { PLAYING, EVALUATING, WON, LOST }

const ROWS := 6
const COLS := 5

signal letter_added(row: int, col: int, letter: String)
signal letter_removed(row: int, col: int)
signal row_evaluated(row: int, results: Array, guess: String)
signal invalid_guess(row: int, reason: String)
signal game_won(row: int, guess_count: int)
signal game_lost(guess_count: int)
signal keyboard_state_changed(states: Dictionary)
signal hint_applied(letter: String)
signal board_reset

var answers: PackedStringArray = []
var allowed_lookup: Dictionary = { }
var answer: String = ""
var guesses: Array[String] = []
var row_results: Array = []
var current_row: int = 0
var current_col: int = 0
var state: GameState = GameState.PLAYING
var keyboard_states: Dictionary = { }
var hard_mode: bool = false
var eliminated_letters: Dictionary = { }

var _daily_key: String = ""


func _ready() -> void:
    _load_word_lists()
    hard_mode = SaveManager.hard_mode
    start_daily_game()


func start_daily_game() -> void:
    _daily_key = _today_key()
    answer = _pick_daily_word()
    guesses.clear()
    row_results.clear()
    guesses.resize(ROWS)
    row_results.resize(ROWS)
    for i in range(ROWS):
        guesses[i] = ""
        row_results.append([])
    current_row = 0
    current_col = 0
    state = GameState.PLAYING
    keyboard_states.clear()
    eliminated_letters.clear()
    SaveManager.record_game_start()
    board_reset.emit()
    keyboard_state_changed.emit(keyboard_states.duplicate())


func add_letter(letter: String) -> bool:
    if state != GameState.PLAYING:
        return false
    if current_col >= COLS:
        return false
    var normalized := letter.to_upper().substr(0, 1)
    if normalized.length() != 1 or normalized[0] < "A" or normalized[0] > "Z":
        return false
    var guess := guesses[current_row]
    guess += normalized
    guesses[current_row] = guess
    letter_added.emit(current_row, current_col, normalized)
    current_col += 1
    return true


func remove_letter() -> bool:
    if state != GameState.PLAYING:
        return false
    if current_col <= 0:
        return false
    current_col -= 1
    var guess := guesses[current_row]
    guess = guess.substr(0, guess.length() - 1)
    guesses[current_row] = guess
    letter_removed.emit(current_row, current_col)
    return true


func submit_guess() -> bool:
    if state != GameState.PLAYING:
        return false
    if current_col != COLS:
        invalid_guess.emit(current_row, "Not enough letters")
        return false

    var guess := guesses[current_row].to_lower()
    if not allowed_lookup.has(guess):
        invalid_guess.emit(current_row, "Not in word list")
        return false

    if hard_mode and not _passes_hard_mode(guess):
        invalid_guess.emit(current_row, "Hard mode: use all revealed hints")
        return false

    state = GameState.EVALUATING
    var results := GuessEvaluator.evaluate(guess.to_upper(), answer.to_upper())
    row_results[current_row] = results

    for i in range(COLS):
        var letter := guess[i].to_upper()
        var current_state: NordTheme.KeyState = keyboard_states.get(letter, NordTheme.KeyState.UNUSED)
        keyboard_states[letter] = GuessEvaluator.to_key_state(results[i], current_state)

    row_evaluated.emit(current_row, results, guess.to_upper())
    keyboard_state_changed.emit(keyboard_states.duplicate())

    if guess == answer:
        state = GameState.WON
        game_won.emit(current_row, current_row + 1)
    elif current_row >= ROWS - 1:
        state = GameState.LOST
        game_lost.emit(ROWS)
    else:
        current_row += 1
        current_col = 0
        state = GameState.PLAYING

    return true


func finish_evaluation() -> void:
    if state == GameState.EVALUATING:
        state = GameState.PLAYING


func apply_hint() -> String:
    if state == GameState.WON or state == GameState.LOST:
        return ""
    if SaveManager.is_hint_used_today():
        return ""

    var candidates: Array[String] = []
    var answer_letters := answer.to_upper()
    for code in range(ord("A"), ord("Z") + 1):
        var letter := char(code)
        if answer_letters.find(letter) != -1:
            continue
        if eliminated_letters.has(letter):
            continue
        if keyboard_states.get(letter, NordTheme.KeyState.UNUSED) == NordTheme.KeyState.ABSENT:
            continue
        candidates.append(letter)

    if candidates.is_empty():
        return ""

    candidates.shuffle()
    var chosen := candidates[0]
    eliminated_letters[chosen] = true
    keyboard_states[chosen] = NordTheme.KeyState.ABSENT
    SaveManager.mark_hint_used()
    hint_applied.emit(chosen)
    keyboard_state_changed.emit(keyboard_states.duplicate())
    return chosen


func set_hard_mode(enabled: bool) -> void:
    hard_mode = enabled
    SaveManager.set_hard_mode(enabled)


func get_guess(row: int) -> String:
    return guesses[row]


func is_game_over() -> bool:
    return state == GameState.WON or state == GameState.LOST


func get_answer() -> String:
    return answer.to_upper()


func _load_word_lists() -> void:
    var answer_words := _read_words("res://data/answers.txt")
    var allowed_words := _read_words("res://data/allowed_guesses.txt")
    answers = answer_words
    allowed_lookup.clear()
    for word in allowed_words:
        allowed_lookup[word] = true
    for word in answer_words:
        allowed_lookup[word] = true


func _read_words(path: String) -> PackedStringArray:
    var words: PackedStringArray = []
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Missing word list: %s" % path)
        return words
    while not file.eof_reached():
        var line := file.get_line().strip_edges().to_lower()
        if line.length() == 5:
            words.append(line)
    return words


func _pick_daily_word() -> String:
    if answers.is_empty():
        return "crane"
    var seed_text := _today_key()
    var index := absi(hash(seed_text)) % answers.size()
    return answers[index]


func _today_key() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


func _passes_hard_mode(guess: String) -> bool:
    for row in range(current_row):
        var previous := guesses[row].to_upper()
        var results: Array = row_results[row]
        if previous.is_empty() or results.is_empty():
            continue
        for col in range(COLS):
            match results[col]:
                GuessEvaluator.LetterResult.CORRECT:
                    if guess[col] != previous[col]:
                        return false
                GuessEvaluator.LetterResult.PRESENT:
                    if guess.find(previous[col]) == -1:
                        return false
    return true
