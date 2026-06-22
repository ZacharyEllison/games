class_name KeyboardKey
extends Control

signal pressed_key(key_id: String)

const KEY_DIR := "res://art/kenney_input-prompts/Keyboard & Mouse/Default/"
const KEY_BACK_LABEL := "←"

var key_id: String = ""
var key_state: NordTheme.KeyState = NordTheme.KeyState.UNUSED
var is_wide: bool = false
var is_eliminated: bool = false

var _button: TextureButton
var _label: Label
var _tween: Tween


func _init(id: String = "", wide: bool = false) -> void:
    key_id = id
    is_wide = wide


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP

    _button = TextureButton.new()
    _button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _button.ignore_texture_size = true
    _button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    _button.texture_normal = _texture_for_key()
    _button.focus_mode = Control.FOCUS_NONE
    _button.pressed.connect(_on_pressed)
    add_child(_button)

    if key_id == "BACK":
        _label = Label.new()
        _label.text = KEY_BACK_LABEL
        _label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        _label.add_theme_font_override("font", NordTheme.icon_font(28))
        _label.add_theme_color_override("font_color", NordTheme.palette().text)
        _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_label)

    apply_key_state(key_state)


func set_key_size(key_size: Vector2) -> void:
    custom_minimum_size = key_size
    pivot_offset = key_size * 0.5
    if _label:
        var icon_size := clampi(int(key_size.y * 0.5), 20, 36)
        _label.add_theme_font_override("font", NordTheme.icon_font(icon_size))


func _on_pressed() -> void:
    if is_eliminated:
        return
    animate_bump()
    pressed_key.emit(key_id)


func _texture_for_key() -> Texture2D:
    match key_id:
        "ENTER":
            return load(KEY_DIR + "keyboard_enter.png")
        "BACK":
            return load(KEY_DIR + "keyboard.png")
        _:
            return load(KEY_DIR + "keyboard_%s.png" % key_id.to_lower())


func apply_key_state(next_state: NordTheme.KeyState) -> void:
    key_state = next_state
    if is_eliminated:
        modulate = Color(0.55, 0.58, 0.62, 0.75)
    elif key_state == NordTheme.KeyState.CORRECT:
        modulate = Color(0.82, 0.95, 0.78)
    elif key_state == NordTheme.KeyState.PRESENT:
        modulate = Color(1.0, 0.95, 0.72)
    elif key_state == NordTheme.KeyState.ABSENT:
        modulate = Color(0.62, 0.66, 0.72)
    else:
        if NordTheme.mode == NordTheme.ThemeMode.LIGHT:
            modulate = NordTheme.palette().key_unused_modulate
        else:
            modulate = Color.WHITE
    if _label:
        _label.add_theme_color_override("font_color", NordTheme.palette().text)
    _button.disabled = is_eliminated


func mark_eliminated() -> void:
    is_eliminated = true
    key_state = NordTheme.KeyState.ABSENT
    apply_key_state(key_state)


func animate_bump() -> void:
    pivot_offset = size * 0.5
    scale = Vector2.ONE
    if _tween and _tween.is_valid():
        _tween.kill()
    _tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.06)
    _tween.tween_property(self, "scale", Vector2.ONE, 0.06)
