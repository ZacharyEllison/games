class_name LetterTile
extends PanelContainer

var tile_state: NordTheme.TileState = NordTheme.TileState.EMPTY
var letter: String = ""

var _label: Label


func _ready() -> void:
    custom_minimum_size = Vector2.ZERO
    pivot_offset = Vector2.ZERO
    _label = Label.new()
    _label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _label.add_theme_font_size_override("font_size", 34)
    add_child(_label)
    apply_theme_state(tile_state, letter)


func set_tile_size(tile_size: Vector2) -> void:
    custom_minimum_size = tile_size
    pivot_offset = tile_size * 0.5
    var font_size := clampi(int(tile_size.y * 0.36), 20, 40)
    _label.add_theme_font_size_override("font_size", font_size)


func set_letter(value: String, animate: bool = true) -> void:
    letter = value
    var next_state := NordTheme.TileState.FILLED if letter.is_empty() == false else NordTheme.TileState.EMPTY
    apply_theme_state(next_state, letter)
    if animate and not letter.is_empty():
        animate_bump()


func apply_theme_state(next_state: NordTheme.TileState, value: String = letter) -> void:
    tile_state = next_state
    letter = value
    var colors := NordTheme.tile_colors(tile_state)
    _label.text = letter
    _label.add_theme_color_override("font_color", colors.text)
    add_theme_stylebox_override("panel", NordTheme.make_panel_style(colors.fill, colors.border, 14, 3))


func reveal_state(next_state: NordTheme.TileState) -> void:
    await animate_flip(next_state)


func animate_bump() -> void:
    pivot_offset = size * 0.5
    scale = Vector2.ONE
    var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.08)
    tween.tween_property(self, "scale", Vector2.ONE, 0.08)


func animate_flip(next_state: NordTheme.TileState) -> void:
    pivot_offset = size * 0.5
    var tween := create_tween()
    tween.tween_property(self, "scale:x", 0.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.tween_callback(func(): apply_theme_state(next_state, letter))
    tween.tween_property(self, "scale:x", 1.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    await tween.finished


func animate_shake() -> void:
    var origin := position
    var tween := create_tween()
    for i in range(6):
        var offset := 6.0 if i % 2 == 0 else -6.0
        tween.tween_property(self, "position:x", origin.x + offset, 0.05)
    tween.tween_property(self, "position:x", origin.x, 0.05)
    await tween.finished


func start_win_float() -> void:
    pivot_offset = size * 0.5
    var tween := create_tween().set_loops()
    tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(self, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
