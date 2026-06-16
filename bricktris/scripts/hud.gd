class_name HUD
extends CanvasLayer

signal reset_requested
signal enter_vr_requested
signal brick_type_selected(type: String)
signal view_preset_selected(preset: int)

const BRICK_GROUPS := [
	{
		"label": "Bricks",
		"types": ["brick_1x1", "brick_1x2", "brick_2x2", "brick_1x4", "brick_2x4"],
	},
	{
		"label": "Plates",
		"types": ["plate_1x1", "plate_1x2", "plate_2x2"],
	},
	{
		"label": "Special",
		"types": ["brick_corner", "brick_slope_1x2"],
	},
]

const TYPE_LABELS := {
	"brick_1x1": "1x1",
	"brick_1x2": "1x2",
	"brick_2x2": "2x2",
	"brick_1x4": "1x4",
	"brick_2x4": "2x4",
	"plate_1x1": "1x1",
	"plate_1x2": "1x2",
	"plate_2x2": "2x2",
	"brick_corner": "Corner",
	"brick_slope_1x2": "Slope",
}

@onready var desktop_enter_vr_btn: Button = %DesktopEnterVRBtn
@onready var desktop_vr_status_label: Label = %DesktopVRStatusLabel
@onready var desktop_reset_btn: Button = %DesktopResetBtn
@onready var desktop_palette: PanelContainer = %DesktopPalette
@onready var palette_list: VBoxContainer = %PaletteList
@onready var view_list: GridContainer = %ViewList
@onready var hint_label: Label = %HintLabel

const VIEW_PRESETS := [
	DesktopCamera.Preset.ORBIT,
	DesktopCamera.Preset.FRONT,
	DesktopCamera.Preset.TOP,
	DesktopCamera.Preset.ORTHO,
	DesktopCamera.Preset.LEFT,
	DesktopCamera.Preset.ISO,
]

var _type_buttons: Dictionary = {}
var _view_buttons: Dictionary = {}
var _selected_type := "brick_1x1"
var _xr_available := false

func _ready() -> void:
	desktop_reset_btn.pressed.connect(func(): reset_requested.emit())
	desktop_enter_vr_btn.pressed.connect(func(): enter_vr_requested.emit())
	desktop_enter_vr_btn.disabled = true
	desktop_vr_status_label.text = "Checking XR support..."
	_show_desktop_ui()
	_build_palette_ui()
	_build_view_ui()

func _build_view_ui() -> void:
	for preset in VIEW_PRESETS:
		var btn := Button.new()
		btn.text = DesktopCamera.preset_name(preset)
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(52, 32)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_view_btn_pressed.bind(preset))
		view_list.add_child(btn)
		_view_buttons[preset] = btn
	_select_view(DesktopCamera.Preset.ORBIT)

func _on_view_btn_pressed(preset: int) -> void:
	_select_view(preset)
	view_preset_selected.emit(preset)

func _select_view(preset: int) -> void:
	for p in _view_buttons:
		(_view_buttons[p] as Button).button_pressed = (p == preset)

func _build_palette_ui() -> void:
	for group in BRICK_GROUPS:
		var section := Label.new()
		section.text = group["label"]
		section.add_theme_font_size_override("font_size", 11)
		section.add_theme_color_override("font_color", Color(0.65, 0.7, 0.82))
		palette_list.add_child(section)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		palette_list.add_child(row)

		for type in group["types"]:
			var btn := _make_brick_button(type)
			row.add_child(btn)
			_type_buttons[type] = btn

	_select_type("brick_1x1")

func _make_brick_button(type: String) -> Button:
	var btn := Button.new()
	btn.text = TYPE_LABELS.get(type, type)
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(52, 40)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(_on_brick_btn_pressed.bind(type))
	return btn

func _on_brick_btn_pressed(type: String) -> void:
	_select_type(type)
	brick_type_selected.emit(type)

func _select_type(type: String) -> void:
	_selected_type = type
	for t in _type_buttons:
		(_type_buttons[t] as Button).button_pressed = (t == type)

func get_selected_type() -> String:
	return _selected_type

func _show_desktop_ui() -> void:
	desktop_palette.show()
	hint_label.show()

func set_vr_status(status: String) -> void:
	match status:
		"supported":
			_xr_available = true
			desktop_enter_vr_btn.disabled = false
			desktop_enter_vr_btn.show()
			desktop_vr_status_label.text = "XR ready (passthrough)"
			desktop_vr_status_label.show()
		"unsupported":
			_xr_available = false
			desktop_enter_vr_btn.hide()
			desktop_vr_status_label.text = "VR not supported in this browser"
			desktop_vr_status_label.show()
		"desktop":
			_xr_available = false
			desktop_enter_vr_btn.hide()
			desktop_vr_status_label.hide()
	_show_desktop_ui()

func on_xr_started() -> void:
	desktop_palette.hide()
	hint_label.hide()

func set_active_view(preset: int) -> void:
	_select_view(preset)

func on_xr_ended() -> void:
	if _xr_available:
		desktop_enter_vr_btn.disabled = false
		desktop_enter_vr_btn.show()
		desktop_vr_status_label.text = "XR ready (passthrough)"
		desktop_vr_status_label.show()
	else:
		desktop_enter_vr_btn.hide()
		desktop_vr_status_label.hide()
	_show_desktop_ui()
