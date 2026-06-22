extends Control

const GRID_PRESETS := [3, 4, 5, 6, 7]
const WIN_LENGTH := 4
const EMPTY_CELL := ""

const BACKGROUND_COLOR := Color8(28, 31, 43)
const PANEL_COLOR := Color8(36, 50, 74)
const PANEL_BORDER_COLOR := Color8(77, 110, 163)
const TILE_IDLE_COLOR := Color8(49, 72, 105)
const TILE_LOCKED_COLOR := Color8(41, 54, 77)
const TEXT_COLOR := Color8(244, 247, 251)
const MUTED_TEXT_COLOR := Color8(168, 179, 201)
const PLAYER_X_COLOR := Color8(255, 134, 104)
const PLAYER_O_COLOR := Color8(90, 212, 195)
const HIGHLIGHT_COLOR := Color8(240, 199, 94)
const DARK_TEXT_COLOR := Color8(30, 34, 48)

var board: Array[String] = []
var cells: Array[PanelContainer] = []
var current_player := "X"
var starting_player := "X"
var game_over := false
var highlighted_line := PackedInt32Array()
var scores := {
    "X": 0,
    "O": 0,
    "Draws": 0,
}
var _x_texture: Texture2D
var _o_texture: Texture2D
var _tween_refs: Array[Tween] = []

var status_label: Label
var score_label: Label

var grid_size := 3
var BOARD_WIDTH: int = 3
var _current_win_lines: Array[PackedInt32Array] = []
var _grid: GridContainer
var _grid_size_layout: HBoxContainer
var _selected_grid_btn: Button
var _board_margin: MarginContainer


func _ready() -> void:
    _build_ui()
    _x_texture = load("res://art/kenney_x.png") as Texture2D
    _o_texture = load("res://art/kenney_o.png") as Texture2D


func _build_ui() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.color = BACKGROUND_COLOR
    add_child(background)

    var shell := MarginContainer.new()
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shell.add_theme_constant_override("margin_left", 24)
    shell.add_theme_constant_override("margin_top", 24)
    shell.add_theme_constant_override("margin_right", 24)
    shell.add_theme_constant_override("margin_bottom", 24)
    add_child(shell)

    var layout := VBoxContainer.new()
    layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
    layout.add_theme_constant_override("separation", 18)
    shell.add_child(layout)

    var title := Label.new()
    title.text = "Tic Tac Toe"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", TEXT_COLOR)
    layout.add_child(title)

    # Grid size preset buttons
    var grid_size_layout := HBoxContainer.new()
    grid_size_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_child(grid_size_layout)
    _grid_size_layout = grid_size_layout

    for preset in GRID_PRESETS:
        var btn := Button.new()
        btn.text = "%d×%d" % [preset, preset]
        btn.custom_minimum_size = Vector2(0, 48)
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _style_action_button(btn, PANEL_COLOR, PANEL_BORDER_COLOR, TEXT_COLOR)
        btn.pressed.connect(_select_grid_size.bind(preset))
        grid_size_layout.add_child(btn)

    _selected_grid_btn = grid_size_layout.get_child(0) as Button
    _selected_grid_btn.add_theme_stylebox_override(
        "normal",
        _make_panel_style(HIGHLIGHT_COLOR.darkened(0.18), HIGHLIGHT_COLOR, 22, 3),
    )

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 26)
    layout.add_child(status_label)

    score_label = Label.new()
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score_label.add_theme_font_size_override("font_size", 20)
    score_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
    layout.add_child(score_label)

    var board_panel := PanelContainer.new()
    board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board_panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR, PANEL_BORDER_COLOR, 28, 4))
    layout.add_child(board_panel)

    var board_margin := MarginContainer.new()
    board_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board_margin.add_theme_constant_override("margin_left", 18)
    board_margin.add_theme_constant_override("margin_top", 18)
    board_margin.add_theme_constant_override("margin_right", 18)
    board_margin.add_theme_constant_override("margin_bottom", 18)
    _apply_board_margins(board_margin, grid_size)
    board_panel.add_child(board_margin)
    _board_margin = board_margin

    var board_center := CenterContainer.new()
    board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board_margin.add_child(board_center)

    var aspect := AspectRatioContainer.new()
    aspect.ratio = 1.0
    aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board_center.add_child(aspect)

    var grid := GridContainer.new()
    grid.columns = grid_size
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 12)
    grid.add_theme_constant_override("v_separation", 12)
    _apply_grid_margins(grid, grid_size)
    _grid = grid
    aspect.add_child(grid)

    for index in range(grid_size * grid_size):
        _create_cell(index, grid)

    var actions := HBoxContainer.new()
    actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_theme_constant_override("separation", 12)
    layout.add_child(actions)

    var new_round_button := Button.new()
    new_round_button.text = "New Round"
    new_round_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    new_round_button.custom_minimum_size = Vector2(0, 64)
    new_round_button.add_theme_font_size_override("font_size", 20)
    _style_action_button(new_round_button, HIGHLIGHT_COLOR, Color8(64, 52, 18), DARK_TEXT_COLOR)
    new_round_button.pressed.connect(_start_round)
    actions.add_child(new_round_button)

    var reset_scores_button := Button.new()
    reset_scores_button.text = "Reset Score"
    reset_scores_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reset_scores_button.custom_minimum_size = Vector2(0, 64)
    reset_scores_button.add_theme_font_size_override("font_size", 20)
    _style_action_button(reset_scores_button, Color8(72, 92, 126), PANEL_BORDER_COLOR, TEXT_COLOR)
    reset_scores_button.pressed.connect(_reset_scores)
    actions.add_child(reset_scores_button)

    var helper_text := Label.new()
    helper_text.text = "Pass-and-play on one device. Tap any tile to place your mark."
    helper_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    helper_text.add_theme_font_size_override("font_size", 18)
    helper_text.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
    helper_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(helper_text)


func _on_cell_input(index: int, event: InputEvent) -> void:
    if event is not InputEventMouseButton:
        return
    var mouse_event := event as InputEventMouseButton
    if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
        return

    var cell := cells[index] as PanelContainer

    if game_over or board[index] != EMPTY_CELL:
        animate_shake(cell)
        return

    board[index] = current_player
    animate_bump(cell)

    # Set the kenney icon texture on this cell's TextureRect
    var mark_rect := _get_mark_texture_rect(cell)
    mark_rect.texture = _x_texture if current_player == "X" else _o_texture

    var winner := _find_winner()
    if winner != EMPTY_CELL:
        game_over = true
        if winner == "DRAW":
            scores["Draws"] += 1
            _set_status("Draw game", HIGHLIGHT_COLOR)
        else:
            scores[winner] += 1
            _set_status("Player %s wins!" % winner, _player_color(winner))
            animate_win_line(highlighted_line)
    else:
        current_player = _next_player(current_player)
        _set_status("Player %s's turn" % current_player, _player_color(current_player))

    _refresh_board()
    _refresh_score()


func _start_round() -> void:
    # Kill all active tweens from previous round (win floats, bump, shake)
    for t in _tween_refs:
        t.kill()
    _tween_refs.clear()
    board.clear()
    for _index in range(grid_size * grid_size):
        board.append(EMPTY_CELL)

    current_player = starting_player
    starting_player = _next_player(starting_player)
    game_over = false
    highlighted_line = PackedInt32Array()
    var effective_wl: int = min(WIN_LENGTH, grid_size)

    _current_win_lines = _build_win_lines(grid_size, effective_wl)

    _set_status("Player %s starts" % current_player, _player_color(current_player))
    _refresh_board()
    _refresh_score()


func _reset_scores() -> void:
    scores["X"] = 0
    scores["O"] = 0
    scores["Draws"] = 0
    starting_player = "X"
    _start_round()


func _refresh_board() -> void:
    for index in range(cells.size()):
        var cell := cells[index] as PanelContainer
        var mark := board[index]
        var is_highlighted := highlighted_line.has(index)
        var is_locked := mark != EMPTY_CELL or game_over

        var fill_color := TILE_IDLE_COLOR
        var border_color := PANEL_BORDER_COLOR
        var cell_modulate := Color.WHITE

        if mark == "X":
            fill_color = PLAYER_X_COLOR.darkened(0.52)
            border_color = PLAYER_X_COLOR
            cell_modulate = PLAYER_X_COLOR
            _get_mark_texture_rect(cell).texture = _x_texture
        elif mark == "O":
            fill_color = PLAYER_O_COLOR.darkened(0.58)
            border_color = PLAYER_O_COLOR
            cell_modulate = PLAYER_O_COLOR
            _get_mark_texture_rect(cell).texture = _o_texture
        elif game_over:
            fill_color = TILE_LOCKED_COLOR
            border_color = PANEL_BORDER_COLOR.darkened(0.2)

        if is_highlighted:
            fill_color = HIGHLIGHT_COLOR.darkened(0.18)
            border_color = HIGHLIGHT_COLOR
            cell_modulate = HIGHLIGHT_COLOR

        cell.add_theme_stylebox_override("panel", _make_panel_style(fill_color, border_color, 24, 4))
        cell.modulate = cell_modulate
        cell.disabled = is_locked


func _refresh_score() -> void:
    score_label.text = "X %d   O %d   Draws %d" % [scores["X"], scores["O"], scores["Draws"]]


func _find_winner() -> String:
    highlighted_line = PackedInt32Array()

    for line in _current_win_lines:
        var first := board[line[0]]
        if first == EMPTY_CELL:
            continue
        var aligned := true
        for k in range(1, line.size()):
            if board[line[k]] != first:
                aligned = false
                break
        if aligned:
            highlighted_line = line
            return first

    # Check draw
    for cell in board:
        if cell == EMPTY_CELL:
            return EMPTY_CELL # not a draw yet

    return "DRAW"


func _next_player(player: String) -> String:
    return "O" if player == "X" else "X"


func _player_color(player: String) -> Color:
    return PLAYER_X_COLOR if player == "X" else PLAYER_O_COLOR


func _set_status(text: String, color: Color) -> void:
    status_label.text = text
    status_label.add_theme_color_override("font_color", color)


func _style_action_button(button: Button, fill_color: Color, border_color: Color, font_color: Color) -> void:
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_color_override("font_color", font_color)
    button.add_theme_color_override("font_hover_color", font_color)
    button.add_theme_color_override("font_pressed_color", font_color)
    button.add_theme_stylebox_override("normal", _make_panel_style(fill_color, border_color, 22, 3))
    button.add_theme_stylebox_override("hover", _make_panel_style(fill_color.lightened(0.06), border_color.lightened(0.08), 22, 3))
    button.add_theme_stylebox_override("pressed", _make_panel_style(fill_color.darkened(0.08), border_color.lightened(0.12), 22, 3))
    button.add_theme_stylebox_override("focus", _make_panel_style(fill_color, HIGHLIGHT_COLOR, 22, 4))


func _make_panel_style(fill_color: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill_color
    style.border_color = border_color
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    return style


func animate_bump(cell: PanelContainer) -> void:
    cell.pivot_offset = cell.size * 0.5
    cell.scale = Vector2.ONE
    var tween := cell.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _tween_refs.append(tween)
    tween.tween_property(cell, "scale", Vector2(1.06, 1.06), 0.08)
    tween.tween_property(cell, "scale", Vector2.ONE, 0.08)


func animate_shake(cell: PanelContainer) -> void:
    var origin := cell.position
    var tween := cell.create_tween()
    _tween_refs.append(tween)
    for i in range(6):
        var offset := 6.0 if i % 2 == 0 else -6.0
        tween.tween_property(cell, "position:x", origin.x + offset, 0.05)
    tween.tween_property(cell, "position:x", origin.x, 0.05)


func animate_win_line(line: PackedInt32Array) -> void:
    for i in range(line.size()):
        var cell := cells[line[i]]
        await get_tree().create_timer(0.1 * i).timeout
        cell.pivot_offset = cell.size * 0.5
        var tween := cell.create_tween().set_loops()
        _tween_refs.append(tween)
        tween.tween_property(cell, "scale", Vector2(1.04, 1.04), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        tween.tween_property(cell, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _get_mark_texture_rect(cell: PanelContainer) -> TextureRect:
    for child in cell.get_children():
        if child is TextureRect:
            return child as TextureRect
    return null

# --- Grid preset helpers ---


func _create_cell(index: int, grid: GridContainer) -> PanelContainer:
    var cell := PanelContainer.new()
    cell.focus_mode = Control.FOCUS_NONE
    cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cell.add_theme_stylebox_override("panel", _make_panel_style(TILE_IDLE_COLOR, PANEL_BORDER_COLOR, 24, 4))
    var mark_texture := TextureRect.new()
    mark_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mark_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    mark_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cell.add_child(mark_texture)
    cell.gui_input.connect(_on_cell_input.bind(index))
    grid.add_child(cell)
    cells.append(cell)
    return cell


func _apply_grid_margins(grid: GridContainer, size: int) -> void:
    if size >= 7:
        grid.add_theme_constant_override("h_separation", 4)
        grid.add_theme_constant_override("v_separation", 4)
    elif size >= 5:
        grid.add_theme_constant_override("h_separation", 8)
        grid.add_theme_constant_override("v_separation", 8)
    else:
        grid.add_theme_constant_override("h_separation", 12)
        grid.add_theme_constant_override("v_separation", 12)


func _apply_board_margins(mc: MarginContainer, size: int) -> void:
    if size >= 7:
        mc.add_theme_constant_override("margin_left", 8)
        mc.add_theme_constant_override("margin_top", 8)
        mc.add_theme_constant_override("margin_right", 8)
        mc.add_theme_constant_override("margin_bottom", 8)
    elif size >= 5:
        mc.add_theme_constant_override("margin_left", 12)
        mc.add_theme_constant_override("margin_top", 12)
        mc.add_theme_constant_override("margin_right", 12)
        mc.add_theme_constant_override("margin_bottom", 12)
    else:
        # default: already set to 18 in _build_ui — no change needed
        pass


func _build_win_lines(gsz: int, wl: int) -> Array[PackedInt32Array]:
    var lines: Array[PackedInt32Array] = []
    var cols := gsz

    # Horizontal (rows)
    for r in range(gsz):
        for start_c in range(cols - wl + 1):
            var line := PackedInt32Array()
            for k in range(wl):
                line.append(r * cols + start_c + k)
            lines.append(line)

    # Vertical (columns)
    for c in range(cols - wl + 1):
        for start_r in range(gsz):
            var line := PackedInt32Array()
            for k in range(wl):
                line.append((start_r + k) * cols + c)
            lines.append(line)

    # Diagonals top-left → bottom-right
    for start_r in range(gsz - wl + 1):
        for start_c in range(cols - wl + 1):
            var line := PackedInt32Array()
            for k in range(wl):
                line.append((start_r + k) * cols + (start_c + k))
            lines.append(line)

    # Diagonals top-right → bottom-left
    for start_r in range(gsz - wl + 1):
        for start_c in range(wl - 1, cols):
            var line := PackedInt32Array()
            for k in range(wl):
                line.append((start_r + k) * cols + (start_c - k))
            lines.append(line)

    return lines


func _select_grid_size(preset: int) -> void:
    if preset == grid_size:
        return # no change needed

    var effective_wl: int = min(WIN_LENGTH, preset)
    var new_win_lines = _build_win_lines(preset, effective_wl)

    # Revert previous button styling
    if _selected_grid_btn:
        _selected_grid_btn.add_theme_stylebox_override(
            "normal",
            _make_panel_style(PANEL_COLOR, PANEL_BORDER_COLOR, 22, 3),
        )

    # Highlight the new active button (match by text)
    for i in range(_grid_size_layout.get_child_count()):
        var child = _grid_size_layout.get_child(i)
        if child is Button:
            var btn := child as Button
            if btn.text == "%d×%d" % [preset, preset]:
                _selected_grid_btn = btn
                btn.add_theme_stylebox_override(
                    "normal",
                    _make_panel_style(HIGHLIGHT_COLOR.darkened(0.18), HIGHLIGHT_COLOR, 22, 3),
                )
                break

    # Rebuild the board
    grid_size = preset
    BOARD_WIDTH = preset
    _current_win_lines = new_win_lines

    for t in _tween_refs:
        t.kill()
    _tween_refs.clear()

    board.clear()
    cells.clear()

    # Remove old cells from grid
    for c in _grid.get_children():
        c.queue_free()

    # Create new cells
    var gsz := grid_size
    _grid.columns = preset
    for idx in range(gsz * gsz):
        _create_cell(idx, _grid)
    _apply_grid_margins(_grid, gsz)
    if _board_margin:
        _apply_board_margins(_board_margin, gsz)

    current_player = starting_player
    starting_player = _next_player(starting_player)
    game_over = false

    _set_status("Player %s starts" % current_player, _player_color(current_player))
    _refresh_board()
    _refresh_score()
