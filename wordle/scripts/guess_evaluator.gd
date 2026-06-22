class_name GuessEvaluator
extends RefCounted

enum LetterResult { ABSENT, PRESENT, CORRECT }


static func evaluate(guess: String, answer: String) -> Array[LetterResult]:
    var results: Array[LetterResult] = []
    results.resize(5)
    for i in range(5):
        results[i] = LetterResult.ABSENT

    var answer_counts: Dictionary = { }
    for i in range(5):
        var letter := answer[i]
        answer_counts[letter] = int(answer_counts.get(letter, 0)) + 1

    for i in range(5):
        if guess[i] == answer[i]:
            results[i] = LetterResult.CORRECT
            answer_counts[guess[i]] = int(answer_counts[guess[i]]) - 1

    for i in range(5):
        if results[i] == LetterResult.CORRECT:
            continue
        var letter := guess[i]
        if int(answer_counts.get(letter, 0)) > 0:
            results[i] = LetterResult.PRESENT
            answer_counts[letter] = int(answer_counts[letter]) - 1

    return results


static func to_tile_state(result: LetterResult) -> NordTheme.TileState:
    match result:
        LetterResult.CORRECT:
            return NordTheme.TileState.CORRECT
        LetterResult.PRESENT:
            return NordTheme.TileState.PRESENT
        _:
            return NordTheme.TileState.ABSENT


static func to_key_state(result: LetterResult, current: NordTheme.KeyState) -> NordTheme.KeyState:
    var candidate := NordTheme.KeyState.UNUSED
    match result:
        LetterResult.CORRECT:
            candidate = NordTheme.KeyState.CORRECT
        LetterResult.PRESENT:
            candidate = NordTheme.KeyState.PRESENT
        _:
            candidate = NordTheme.KeyState.ABSENT
    return _max_key_state(current, candidate)


static func _max_key_state(a: NordTheme.KeyState, b: NordTheme.KeyState) -> NordTheme.KeyState:
    var rank := {
        NordTheme.KeyState.UNUSED: 0,
        NordTheme.KeyState.ABSENT: 1,
        NordTheme.KeyState.PRESENT: 2,
        NordTheme.KeyState.CORRECT: 3,
    }
    return a if rank[a] >= rank[b] else b
