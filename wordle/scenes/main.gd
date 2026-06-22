extends Control

const LetterTileScene := preload("res://scripts/letter_tile.gd")
const KeyboardKeyScene := preload("res://scripts/keyboard_key.gd")
const THEME_ICON_LIGHT := "★"
const THEME_ICON_DARK := "☽"

const ROWS := 6
const COLS := 5
const KEYBOARD_ROWS := [
    ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
    ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
    ["BACK", "Z", "X", "C", "V", "B", "N", "M"],
]
const KEYBOARD_HEIGHT_RATIO := 0.4
const KEYBOARD_KEY_GAP := 6.0
const KEYBOARD_KEY_ASPECT := 0.78
const KEYBOARD_WIDE_WIDTH_SCALE := 1.55
const KEYBOARD_MAX_KEY_HEIGHT := 58.0

var _theme_controls: Array[Button] = []
var _theme_panels: Array[PanelContainer] = []
var _theme_muted_labels: Array[Label] = []
var _theme_labels: Array[Label] = []

var _background: ColorRect
var _header_label: Label
var _status_label: Label
var _board_panel: PanelContainer
var _board_grid: GridContainer
var _board_area: Control
var _play_area: VBoxContainer
var _keyboard_section: VBoxContainer
var _keyboard_root: VBoxContainer
var _pause_overlay: ColorRect
var _pause_menu: VBoxContainer
var _pause_panel: PanelContainer
var _stats_panel: Label
var _hard_mode_toggle: CheckButton
var _hint_button: Button
var _theme_toggle: Button
var _tiles: Array[LetterTile] = []
var _keyboard_keys: Dictionary = { }
var _keyboard_rows: Array[HBoxContainer] = []
var _evaluating: bool = false
var _input_locked: bool = false
var _fx_layer: CanvasLayer
var _fx_root: Control
var _last_letter_source: Control
var _confetti_pending: bool = false
var _win_row: int = -1
var _win_guess_count: int = 0


func _ready() -> void:
    Input.set_emulate_touch_from_mouse(true)
    _build_ui()
    _connect_signals()
    _apply_theme()
    _refresh_header()
    _refresh_stats()
    _check_daily_completion()
    call_deferred("_layout_keyboard")
    call_deferred("_layout_board")


func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_keyboard")
        call_deferred("_layout_board")


func _unhandled_input(event: InputEvent) -> void:
    if _pause_overlay.visible or _input_locked:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        var key_event := event as InputEventKey
        if key_event.keycode == KEY_BACKSPACE:
            _on_backspace()
        elif key_event.keycode >= KEY_A and key_event.keycode <= KEY_Z:
            var letter := char(key_event.keycode)
            var key_node: KeyboardKey = _keyboard_keys.get(letter, null)
            _last_letter_source = key_node
            _on_letter(letter)
            if key_node:
                key_node.animate_bump()


func _build_ui() -> void:
    _background = ColorRect.new()
    _background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_background)

    _fx_layer = CanvasLayer.new()
    _fx_layer.layer = 20
    add_child(_fx_layer)

    _fx_root = Control.new()
    _fx_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _fx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fx_layer.add_child(_fx_root)

    var shell := MarginContainer.new()
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shell.add_theme_constant_override("margin_left", 20)
    shell.add_theme_constant_override("margin_top", 20)
    shell.add_theme_constant_override("margin_right", 20)
    shell.add_theme_constant_override("margin_bottom", 20)
    add_child(shell)

    var body := Control.new()
    body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    shell.add_child(body)

    _play_area = VBoxContainer.new()
    _play_area.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _play_area.anchor_bottom = 1.0 - KEYBOARD_HEIGHT_RATIO
    _play_area.offset_left = 0
    _play_area.offset_top = 0
    _play_area.offset_right = 0
    _play_area.offset_bottom = 0
    _play_area.add_theme_constant_override("separation", 14)
    body.add_child(_play_area)

    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 12)
    _play_area.add_child(top_row)

    _header_label = Label.new()
    _header_label.text = "WORDLE"
    _header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _header_label.add_theme_font_size_override("font_size", 34)
    top_row.add_child(_header_label)

    var corner_actions := HBoxContainer.new()
    corner_actions.add_theme_constant_override("separation", 8)
    top_row.add_child(corner_actions)

    _theme_toggle = Button.new()
    _theme_toggle.custom_minimum_size = Vector2(42, 42)
    _theme_toggle.add_theme_font_size_override("font_size", 22)
    _theme_toggle.tooltip_text = "Toggle theme"
    _theme_toggle.pressed.connect(_on_theme_toggle)
    corner_actions.add_child(_theme_toggle)

    var pause_button := Button.new()
    pause_button.text = "Settings"
    pause_button.custom_minimum_size = Vector2(96, 48)
    pause_button.pressed.connect(_open_pause)
    corner_actions.add_child(pause_button)
    _theme_controls.append(pause_button)

    _board_area = Control.new()
    _board_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _play_area.add_child(_board_area)

    var board_area_center := CenterContainer.new()
    board_area_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _board_area.add_child(board_area_center)

    var board_stack := VBoxContainer.new()
    board_stack.add_theme_constant_override("separation", 10)
    board_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board_area_center.add_child(board_stack)

    var board_panel := PanelContainer.new()
    board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board_stack.add_child(board_panel)
    _board_panel = board_panel
    _theme_panels.append(board_panel)

    var board_margin := MarginContainer.new()
    board_margin.add_theme_constant_override("margin_left", 12)
    board_margin.add_theme_constant_override("margin_top", 12)
    board_margin.add_theme_constant_override("margin_right", 12)
    board_margin.add_theme_constant_override("margin_bottom", 12)
    board_panel.add_child(board_margin)

    _board_grid = GridContainer.new()
    _board_grid.columns = COLS
    _board_grid.add_theme_constant_override("h_separation", 8)
    _board_grid.add_theme_constant_override("v_separation", 8)
    board_margin.add_child(_board_grid)

    for row in range(ROWS):
        for col in range(COLS):
            var tile := LetterTileScene.new()
            _board_grid.add_child(tile)
            _tiles.append(tile)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.add_theme_font_size_override("font_size", 20)
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    board_stack.add_child(_status_label)

    _keyboard_section = VBoxContainer.new()
    _keyboard_section.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _keyboard_section.anchor_top = 1.0 - KEYBOARD_HEIGHT_RATIO
    _keyboard_section.offset_left = 0
    _keyboard_section.offset_top = 0
    _keyboard_section.offset_right = 0
    _keyboard_section.offset_bottom = 0
    _keyboard_section.add_theme_constant_override("separation", 10)
    body.add_child(_keyboard_section)

    var keyboard_shell := Control.new()
    keyboard_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    keyboard_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _keyboard_section.add_child(keyboard_shell)

    var keyboard_center := CenterContainer.new()
    keyboard_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    keyboard_shell.add_child(keyboard_center)

    _keyboard_root = VBoxContainer.new()
    _keyboard_root.add_theme_constant_override("separation", 8)
    keyboard_center.add_child(_keyboard_root)
    _build_keyboard()

    _build_pause_overlay()


func _build_keyboard() -> void:
    for row_keys in KEYBOARD_ROWS:
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", int(KEYBOARD_KEY_GAP))
        _keyboard_root.add_child(row)
        _keyboard_rows.append(row)

        for key_id in row_keys:
            var wide: bool = key_id == "BACK"
            var key := KeyboardKeyScene.new(key_id, wide)
            key.pressed_key.connect(_on_keyboard_key)
            row.add_child(key)
            if key_id != "BACK":
                _keyboard_keys[key_id] = key


func _layout_board() -> void:
    if _board_area == null or _tiles.is_empty():
        return

    var status_h: float = _status_label.get_combined_minimum_size().y
    var stack_sep: float = 10.0
    var inner_w: float = maxf(_board_area.size.x - 24.0, 240.0)
    var inner_h: float = maxf(_board_area.size.y - status_h - stack_sep - 24.0, 200.0)
    var h_sep: float = float(_board_grid.get_theme_constant("h_separation"))
    var v_sep: float = float(_board_grid.get_theme_constant("v_separation"))
    var tile_w: float = (inner_w - h_sep * float(COLS - 1)) / float(COLS)
    var tile_h: float = (inner_h - v_sep * float(ROWS - 1)) / float(ROWS)
    var tile_size: float = floorf(minf(tile_w, tile_h))
    tile_size = clampf(tile_size, 48.0, 88.0)

    for tile in _tiles:
        tile.set_tile_size(Vector2(tile_size, tile_size))


func _layout_keyboard() -> void:
    if _keyboard_section == null or _keyboard_rows.is_empty():
        return

    var row_gap := 8
    var viewport_w := maxf(size.x - 40.0, 320.0)
    var key_w: float = (viewport_w - KEYBOARD_KEY_GAP * 9.0) / 10.0
    var key_h: float = minf(key_w * KEYBOARD_KEY_ASPECT, KEYBOARD_MAX_KEY_HEIGHT)

    _keyboard_root.add_theme_constant_override("separation", row_gap)
    for row in _keyboard_rows:
        row.custom_minimum_size.y = key_h
        for child in row.get_children():
            if child is KeyboardKey:
                var keyboard_key: KeyboardKey = child
                var key_width: float = key_w * (KEYBOARD_WIDE_WIDTH_SCALE if keyboard_key.is_wide else 1.0)
                keyboard_key.set_key_size(Vector2(key_width, key_h))


func _build_pause_overlay() -> void:
    _pause_overlay = ColorRect.new()
    _pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _pause_overlay.visible = false
    _pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_pause_overlay)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _pause_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(560, 0)
    center.add_child(panel)
    _pause_panel = panel
    _theme_panels.append(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    panel.add_child(margin)

    _pause_menu = VBoxContainer.new()
    _pause_menu.add_theme_constant_override("separation", 14)
    margin.add_child(_pause_menu)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    _pause_menu.add_child(header)

    var title := Label.new()
    title.text = "Settings"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 28)
    header.add_child(title)
    _theme_labels.append(title)

    var close_button := Button.new()
    close_button.text = "×"
    close_button.custom_minimum_size = Vector2(40, 40)
    close_button.add_theme_font_size_override("font_size", 28)
    close_button.pressed.connect(_close_pause)
    header.add_child(close_button)
    _theme_controls.append(close_button)

    _stats_panel = Label.new()
    _stats_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _stats_panel.add_theme_font_size_override("font_size", 17)
    _pause_menu.add_child(_stats_panel)
    _theme_muted_labels.append(_stats_panel)

    _hard_mode_toggle = CheckButton.new()
    _hard_mode_toggle.text = ""
    _hard_mode_toggle.focus_mode = Control.FOCUS_NONE
    _hard_mode_toggle.custom_minimum_size = Vector2(52, 32)
    _hard_mode_toggle.button_pressed = SaveManager.hard_mode
    _hard_mode_toggle.toggled.connect(_on_hard_mode_toggled)
    _pause_menu.add_child(
        _make_settings_row(
            "Hard Mode",
            "Any revealed hints must be used in subsequent guesses",
            _hard_mode_toggle,
        ),
    )

    _hint_button = Button.new()
    _hint_button.text = "Use"
    _hint_button.custom_minimum_size = Vector2(72, 36)
    _hint_button.pressed.connect(_on_hint_pressed)
    _theme_controls.append(_hint_button)
    _pause_menu.add_child(
        _make_settings_row(
            "Letter Hint",
            "Eliminate one wrong letter from the keyboard (once per day)",
            _hint_button,
        ),
    )


func _make_settings_row(title_text: String, description: String, action: Control) -> PanelContainer:
    var row_panel := PanelContainer.new()
    _theme_panels.append(row_panel)

    var row_margin := MarginContainer.new()
    row_margin.add_theme_constant_override("margin_left", 14)
    row_margin.add_theme_constant_override("margin_top", 12)
    row_margin.add_theme_constant_override("margin_right", 14)
    row_margin.add_theme_constant_override("margin_bottom", 12)
    row_panel.add_child(row_margin)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    row_margin.add_child(row)

    var text_col := VBoxContainer.new()
    text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_col.add_theme_constant_override("separation", 4)
    row.add_child(text_col)

    var row_title := Label.new()
    row_title.text = title_text
    row_title.add_theme_font_size_override("font_size", 18)
    text_col.add_child(row_title)
    _theme_labels.append(row_title)

    var row_desc := Label.new()
    row_desc.text = description
    row_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    row_desc.add_theme_font_size_override("font_size", 14)
    text_col.add_child(row_desc)
    _theme_muted_labels.append(row_desc)

    action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(action)

    return row_panel


func _connect_signals() -> void:
    WordleGame.letter_added.connect(_on_letter_added)
    WordleGame.letter_removed.connect(_on_letter_removed)
    WordleGame.row_evaluated.connect(_on_row_evaluated)
    WordleGame.invalid_guess.connect(_on_invalid_guess)
    WordleGame.game_won.connect(_on_game_won)
    WordleGame.game_lost.connect(_on_game_lost)
    WordleGame.keyboard_state_changed.connect(_on_keyboard_state_changed)
    WordleGame.hint_applied.connect(_on_hint_applied)
    WordleGame.board_reset.connect(_on_board_reset)
    NordTheme.theme_changed.connect(func(_mode): _apply_theme())
    SaveManager.data_changed.connect(_refresh_stats)


func _check_daily_completion() -> void:
    if SaveManager.today_completed and SaveManager.last_completed_date == _today_key():
        _input_locked = true
        if SaveManager.today_won:
            _set_status("You already solved today's puzzle. Come back tomorrow!", NordTheme.palette().accent)
        else:
            _set_status("Today's puzzle is done. The word was %s." % WordleGame.get_answer(), NordTheme.ABSENT)
        _disable_input()


func _disable_input() -> void:
    for key in _keyboard_keys.values():
        key.mark_eliminated()


func _on_board_reset() -> void:
    for tile in _tiles:
        tile.set_letter("", false)
        tile.apply_theme_state(NordTheme.TileState.EMPTY, "")
    for key in _keyboard_keys.values():
        key.is_eliminated = false
        key.apply_key_state(NordTheme.KeyState.UNUSED)
    _set_status("Guess the daily five-letter word.", NordTheme.palette().muted_text)


func _on_letter_added(row: int, col: int, letter: String) -> void:
    var tile := _tile_at(row, col)
    var source := _last_letter_source
    _last_letter_source = null
    await _fly_letter_to_tile(letter, tile, source)
    if col == COLS - 1:
        _submit_guess()


func _fly_letter_to_tile(letter: String, tile: LetterTile, source: Control) -> void:
    var palette := NordTheme.palette()
    var end := tile.get_global_rect().get_center()
    var start := end
    if source:
        start = source.get_global_rect().get_center()
    elif _keyboard_section:
        var kb_rect := _keyboard_section.get_global_rect()
        start = Vector2(end.x, kb_rect.position.y + kb_rect.size.y * 0.45)

    var flyer := Label.new()
    flyer.text = letter
    flyer.add_theme_font_size_override("font_size", clampi(int(tile.custom_minimum_size.y * 0.36), 20, 40))
    flyer.add_theme_color_override("font_color", palette.text)
    flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fx_root.add_child(flyer)
    await get_tree().process_frame
    flyer.global_position = start - flyer.size * 0.5
    flyer.scale = Vector2(0.85, 0.85)
    flyer.modulate.a = 0.92

    var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(flyer, "global_position", end - flyer.size * 0.5, 0.2)
    tween.parallel().tween_property(flyer, "scale", Vector2.ONE, 0.2)
    tween.parallel().tween_property(flyer, "modulate:a", 1.0, 0.12)
    await tween.finished
    flyer.queue_free()
    tile.set_letter(letter, true)


func _on_letter_removed(row: int, col: int) -> void:
    var tile := _tile_at(row, col)
    tile.set_letter("", false)


func _on_row_evaluated(row: int, results: Array, _guess: String) -> void:
    _evaluating = true
    for col in range(COLS):
        var tile := _tile_at(row, col)
        var next_state := GuessEvaluator.to_tile_state(results[col])
        await tile.reveal_state(next_state)
        await get_tree().create_timer(0.05).timeout
    _evaluating = false
    if _confetti_pending:
        _confetti_pending = false
        _play_win_celebration(_win_row, _win_guess_count)


func _on_invalid_guess(row: int, reason: String) -> void:
    _set_status(reason, NordTheme.PRESENT)
    for col in range(COLS):
        await _tile_at(row, col).animate_shake()


func _on_game_won(row: int, guess_count: int) -> void:
    _input_locked = true
    _confetti_pending = true
    _win_row = row
    _win_guess_count = guess_count
    SaveManager.record_win(guess_count)
    _refresh_stats()


func _play_win_celebration(row: int, guess_count: int) -> void:
    _set_status("You win! +%d points" % SaveManager.points_for_guess_count(guess_count), NordTheme.CORRECT)
    var origin := _board_panel.get_global_rect().get_center()
    ConfettiEffect.burst(_fx_root, origin)
    for col in range(COLS):
        _tile_at(row, col).start_win_float()


func _on_game_lost(guess_count: int) -> void:
    _input_locked = true
    SaveManager.record_loss(guess_count)
    _set_status("The word was %s" % WordleGame.get_answer(), NordTheme.ABSENT)
    _refresh_stats()


func _on_keyboard_state_changed(states: Dictionary) -> void:
    for letter in states.keys():
        var key: KeyboardKey = _keyboard_keys.get(letter, null)
        if key:
            key.apply_key_state(states[letter])
            key.animate_bump()


func _on_hint_applied(letter: String) -> void:
    var key: KeyboardKey = _keyboard_keys.get(letter, null)
    if key:
        key.mark_eliminated()
    _refresh_pause_menu()


func _on_keyboard_key(key_id: String) -> void:
    if key_id == "BACK":
        _on_backspace()
    else:
        _last_letter_source = _keyboard_keys.get(key_id, null)
        _on_letter(key_id)


func _on_letter(letter: String) -> void:
    if _input_locked or _evaluating or WordleGame.is_game_over():
        return
    WordleGame.add_letter(letter)


func _on_backspace() -> void:
    if _input_locked or _evaluating or WordleGame.is_game_over():
        return
    WordleGame.remove_letter()


func _submit_guess() -> void:
    if _input_locked or _evaluating or WordleGame.is_game_over():
        return
    WordleGame.submit_guess()


func _open_pause() -> void:
    _refresh_pause_menu()
    _pause_overlay.visible = true
    _animate_pause_in()


func _close_pause() -> void:
    _pause_overlay.visible = false


func _on_hard_mode_toggled(enabled: bool) -> void:
    WordleGame.set_hard_mode(enabled)


func _on_hint_pressed() -> void:
    var letter := WordleGame.apply_hint()
    if letter.is_empty():
        _set_status("No hint available right now.", NordTheme.palette().muted_text)
    _refresh_pause_menu()


func _on_theme_toggle() -> void:
    NordTheme.toggle_mode()


func _animate_pause_in() -> void:
    for i in _pause_menu.get_child_count():
        var node := _pause_menu.get_child(i)
        if node is Control:
            node.scale = Vector2(0.3, 0.3)
            node.pivot_offset = node.size * 0.5
            var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
            tween.tween_interval(i * 0.04)
            tween.tween_property(node, "scale", Vector2.ONE, 0.24)


func _apply_theme() -> void:
    var palette := NordTheme.palette()
    NordTheme.animate_color_rect(_background, palette.background)
    _header_label.add_theme_color_override("font_color", palette.text)
    _status_label.add_theme_color_override("font_color", palette.muted_text)
    _pause_overlay.color = palette.overlay

    for panel in _theme_panels:
        if panel == _pause_panel:
            panel.add_theme_stylebox_override("panel", NordTheme.make_panel_style(palette.panel, palette.panel_border, 24, 3))
        elif NordTheme.mode == NordTheme.ThemeMode.LIGHT:
            panel.add_theme_stylebox_override("panel", NordTheme.make_panel_style(palette.panel, palette.panel_border, 18, 3))
        else:
            panel.add_theme_stylebox_override("panel", NordTheme.make_panel_style(palette.panel.lightened(0.02), palette.panel_border.darkened(0.08), 18, 2))

    for label in _theme_labels:
        label.add_theme_color_override("font_color", palette.text)

    for label in _theme_muted_labels:
        label.add_theme_color_override("font_color", palette.muted_text)

    for button in _theme_controls:
        if NordTheme.mode == NordTheme.ThemeMode.LIGHT:
            NordTheme.style_button(button, palette.key_fill, palette.key_border, palette.text)
        else:
            NordTheme.style_button(button, palette.panel.lightened(0.04), palette.panel_border, palette.text)

    _style_theme_toggle(palette)
    _style_settings_toggle(_hard_mode_toggle, palette)

    for tile in _tiles:
        tile.apply_theme_state(tile.tile_state, tile.letter)

    for key in _keyboard_keys.values():
        key.apply_key_state(key.key_state)


func _style_theme_toggle(palette: Dictionary) -> void:
    _theme_toggle.focus_mode = Control.FOCUS_NONE
    _theme_toggle.text = THEME_ICON_LIGHT if NordTheme.mode == NordTheme.ThemeMode.DARK else THEME_ICON_DARK
    _theme_toggle.add_theme_font_override("font", NordTheme.icon_font(22))
    _theme_toggle.add_theme_color_override("font_color", palette.text)
    _theme_toggle.add_theme_color_override("font_hover_color", palette.text)
    _theme_toggle.add_theme_color_override("font_pressed_color", palette.text)
    _theme_toggle.add_theme_stylebox_override("normal", NordTheme.make_panel_style(palette.toggle_bg, palette.toggle_bg, 21, 0))
    _theme_toggle.add_theme_stylebox_override("hover", NordTheme.make_panel_style(palette.toggle_hover, palette.toggle_hover, 21, 0))
    _theme_toggle.add_theme_stylebox_override("pressed", NordTheme.make_panel_style(palette.toggle_hover.darkened(0.05), palette.toggle_hover.darkened(0.05), 21, 0))
    _theme_toggle.add_theme_stylebox_override("focus", NordTheme.make_panel_style(palette.toggle_bg, palette.accent, 21, 2))


func _style_settings_toggle(toggle: CheckButton, palette: Dictionary) -> void:
    toggle.add_theme_color_override("font_color", palette.text)
    toggle.add_theme_color_override("font_hover_color", palette.text)
    toggle.add_theme_color_override("font_pressed_color", palette.text)
    var off_bg: Color = (palette.panel_border as Color).darkened(0.12)
    var on_bg: Color = NordTheme.CORRECT
    var off_style: StyleBoxFlat = NordTheme.make_panel_style(off_bg, off_bg, 12, 0)
    var on_style: StyleBoxFlat = NordTheme.make_panel_style(on_bg, on_bg.darkened(0.08), 12, 0)
    toggle.add_theme_stylebox_override("normal", off_style)
    toggle.add_theme_stylebox_override("hover", NordTheme.make_panel_style(off_bg.lightened(0.06), off_bg.lightened(0.06), 12, 0))
    toggle.add_theme_stylebox_override("pressed", on_style)
    toggle.add_theme_stylebox_override("disabled", NordTheme.make_panel_style(off_bg.darkened(0.08), off_bg.darkened(0.08), 12, 0))
    toggle.add_theme_stylebox_override("focus", NordTheme.make_panel_style(off_bg, palette.accent, 12, 2))
    toggle.add_theme_stylebox_override("checked", on_style)
    toggle.add_theme_stylebox_override("checked_hover", on_style)
    toggle.add_theme_stylebox_override("checked_pressed", on_style)
    toggle.add_theme_stylebox_override("checked_focus", NordTheme.make_panel_style(on_bg, palette.accent, 12, 2))


func _refresh_header() -> void:
    var dt := Time.get_datetime_dict_from_system()
    var weekday := _weekday_name(dt.weekday)
    _header_label.text = "WORDLE · %s %d/%d" % [weekday, dt.month, dt.day]


func _refresh_stats() -> void:
    _refresh_pause_menu()


func _refresh_pause_menu() -> void:
    var hint_state := "available" if not SaveManager.is_hint_used_today() else "used today"
    _stats_panel.text = "Points %d  ·  Streak %d  ·  Best %d\nGames %d  ·  Wins %d\n\nGuess distribution\n%s" % [
        SaveManager.total_points,
        SaveManager.current_streak,
        SaveManager.best_streak,
        SaveManager.games_played,
        SaveManager.games_won,
        SaveManager.distribution_summary(),
    ]
    _hint_button.disabled = SaveManager.is_hint_used_today() or WordleGame.is_game_over()
    _hint_button.text = "Used" if SaveManager.is_hint_used_today() else "Use"


func _set_status(text: String, color: Color) -> void:
    _status_label.text = text
    _status_label.add_theme_color_override("font_color", color)


func _tile_at(row: int, col: int) -> LetterTile:
    return _tiles[row * COLS + col]


func _today_key() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


func _weekday_name(index: int) -> String:
    var names := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    return names[clampi(index, 0, 6)]
