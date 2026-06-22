extends Node

enum ThemeMode { LIGHT, DARK }

enum TileState { EMPTY, FILLED, ABSENT, PRESENT, CORRECT }

enum KeyState { UNUSED, ABSENT, PRESENT, CORRECT }

var mode: ThemeMode = ThemeMode.DARK

const LIGHT := {
    "background": Color("#eceff4"),
    "panel": Color("#e5e9f0"),
    "panel_border": Color("#8899ad"),
    "text": Color("#2e3440"),
    "muted_text": Color("#434c5e"),
    "tile_empty_fill": Color("#e5e9f0"),
    "tile_empty_border": Color("#8899ad"),
    "tile_filled_fill": Color("#d8dee9"),
    "tile_filled_border": Color("#697385"),
    "key_fill": Color("#d8dee9"),
    "key_border": Color("#697385"),
    "key_unused_modulate": Color(0.56, 0.62, 0.72),
    "accent": Color("#5e81ac"),
    "overlay": Color(46, 52, 64, 0.62),
    "toggle_bg": Color(46, 52, 64, 0.12),
    "toggle_hover": Color(46, 52, 64, 0.22),
}

const DARK := {
    "background": Color("#2e3440"),
    "panel": Color("#3b4252"),
    "panel_border": Color("#434c5e"),
    "text": Color("#eceff4"),
    "muted_text": Color("#d8dee9"),
    "tile_empty_fill": Color("#3b4252"),
    "tile_empty_border": Color("#434c5e"),
    "tile_filled_fill": Color("#434c5e"),
    "tile_filled_border": Color("#4c566a"),
    "key_fill": Color("#434c5e"),
    "key_border": Color("#4c566a"),
    "accent": Color("#88c0d0"),
    "overlay": Color(15, 17, 22, 0.72),
    "toggle_bg": Color(236, 239, 244, 0.08),
    "toggle_hover": Color(236, 239, 244, 0.16),
}

const ABSENT := Color("#4c566a")
const PRESENT := Color("#ebcb8b")
const CORRECT := Color("#a3be8c")
const PRESENT_TEXT := Color("#2e3440")
const CORRECT_TEXT := Color("#2e3440")

const ICON_FONT_PATH := "res://fonts/NotoSansSymbols2-Regular.ttf"

var _icon_font_base: FontFile

signal theme_changed(mode: ThemeMode)


func _ready() -> void:
    mode = ThemeMode.DARK if SaveManager.get_theme() == "dark" else ThemeMode.LIGHT


func palette() -> Dictionary:
    return DARK if mode == ThemeMode.DARK else LIGHT


func icon_font(size: int = 22) -> Font:
    if _icon_font_base == null:
        _icon_font_base = load(ICON_FONT_PATH) as FontFile
    var font := FontVariation.new()
    font.base_font = _icon_font_base
    font.set_size(size)
    return font


func set_mode(next_mode: ThemeMode) -> void:
    if mode == next_mode:
        return
    mode = next_mode
    SaveManager.set_theme("dark" if mode == ThemeMode.DARK else "light")
    theme_changed.emit(mode)


func toggle_mode() -> void:
    set_mode(ThemeMode.LIGHT if mode == ThemeMode.DARK else ThemeMode.DARK)


func tile_colors(state: TileState) -> Dictionary:
    var p := palette()
    match state:
        TileState.EMPTY:
            return { "fill": p.tile_empty_fill, "border": p.tile_empty_border, "text": p.text }
        TileState.FILLED:
            return { "fill": p.tile_filled_fill, "border": p.tile_filled_border, "text": p.text }
        TileState.ABSENT:
            return { "fill": ABSENT, "border": ABSENT.darkened(0.1), "text": Color.WHITE }
        TileState.PRESENT:
            return { "fill": PRESENT, "border": PRESENT.darkened(0.08), "text": PRESENT_TEXT }
        TileState.CORRECT:
            return { "fill": CORRECT, "border": CORRECT.darkened(0.08), "text": CORRECT_TEXT }
    return { "fill": p.tile_empty_fill, "border": p.tile_empty_border, "text": p.text }


func key_colors(state: KeyState) -> Dictionary:
    match state:
        KeyState.ABSENT:
            return { "fill": ABSENT, "border": ABSENT.darkened(0.1), "text": Color.WHITE, "modulate": Color.WHITE }
        KeyState.PRESENT:
            return { "fill": PRESENT, "border": PRESENT.darkened(0.08), "text": PRESENT_TEXT, "modulate": Color.WHITE }
        KeyState.CORRECT:
            return { "fill": CORRECT, "border": CORRECT.darkened(0.08), "text": CORRECT_TEXT, "modulate": Color.WHITE }
        _:
            var p := palette()
            return { "fill": p.key_fill, "border": p.key_border, "text": p.text, "modulate": Color.WHITE }


func make_panel_style(fill_color: Color, border_color: Color, radius: int = 16, border_width: int = 3) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill_color
    style.border_color = border_color
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    return style


func style_button(button: Button, fill_color: Color, border_color: Color, font_color: Color, radius: int = 18) -> void:
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_color_override("font_color", font_color)
    button.add_theme_color_override("font_hover_color", font_color)
    button.add_theme_color_override("font_pressed_color", font_color)
    button.add_theme_color_override("font_disabled_color", font_color.lightened(0.2))
    button.add_theme_stylebox_override("normal", make_panel_style(fill_color, border_color, radius, 3))
    button.add_theme_stylebox_override("hover", make_panel_style(fill_color.lightened(0.06), border_color.lightened(0.08), radius, 3))
    button.add_theme_stylebox_override("pressed", make_panel_style(fill_color.darkened(0.08), border_color.lightened(0.12), radius, 3))
    button.add_theme_stylebox_override("disabled", make_panel_style(fill_color.darkened(0.12), border_color.darkened(0.08), radius, 3))
    button.add_theme_stylebox_override("focus", make_panel_style(fill_color, palette().accent, radius, 4))


func animate_color_rect(rect: ColorRect, target: Color, duration: float = 0.25) -> void:
    var tween := rect.create_tween()
    tween.tween_property(rect, "color", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
