class_name HUD
extends CanvasLayer

signal reset_requested
signal enter_vr_requested
signal brick_type_selected(type: String)

const BRICK_LABELS := {
	"brick_1x1":       "1x1",
	"brick_1x2":       "1x2",
	"brick_2x2":       "2x2",
	"brick_1x4":       "1x4",
	"brick_2x4":       "2x4",
	"plate_1x1":       "Plate\n1x1",
	"plate_1x2":       "Plate\n1x2",
	"plate_2x2":       "Plate\n2x2",
	"brick_corner":    "Corner",
	"brick_slope_1x2": "Slope",
}

@onready var enter_vr_btn: Button     = %EnterVRBtn
@onready var vr_status_label: Label   = %VRStatusLabel
@onready var reset_btn: Button        = %ResetBtn
@onready var desktop_hint: Label      = %DesktopHint
@onready var bottom_bar: PanelContainer = %BottomBar
@onready var brick_row: HBoxContainer = %BrickRow

var _type_buttons: Dictionary = {}
var _selected_type := "brick_1x1"

func _ready() -> void:
	reset_btn.pressed.connect(func(): reset_requested.emit())
	enter_vr_btn.pressed.connect(func(): enter_vr_requested.emit())
	enter_vr_btn.disabled = true
	vr_status_label.text = "Checking VR support..."
	desktop_hint.hide()
	_build_brick_buttons()

func _build_brick_buttons() -> void:
	for type in BRICK_LABELS.keys():
		var btn := Button.new()
		btn.text = BRICK_LABELS[type]
		btn.custom_minimum_size = Vector2(56, 44)
		btn.toggle_mode = true
		btn.button_pressed = (type == _selected_type)
		btn.pressed.connect(_on_brick_btn_pressed.bind(type, btn))
		brick_row.add_child(btn)
		_type_buttons[type] = btn

func _on_brick_btn_pressed(type: String, pressed_btn: Button) -> void:
	_selected_type = type
	brick_type_selected.emit(type)
	for t in _type_buttons:
		(_type_buttons[t] as Button).button_pressed = (t == type)

func get_selected_type() -> String:
	return _selected_type

func set_vr_status(status: String) -> void:
	match status:
		"supported":
			enter_vr_btn.disabled = false
			vr_status_label.text = "VR ready"
		"unsupported":
			enter_vr_btn.disabled = true
			vr_status_label.text = "VR not supported in this browser"
		"desktop":
			enter_vr_btn.hide()
			vr_status_label.hide()
			desktop_hint.text = "Desktop mode"
			desktop_hint.show()
			bottom_bar.show()

func on_xr_started() -> void:
	enter_vr_btn.hide()
	vr_status_label.hide()
	bottom_bar.hide()

func on_xr_ended() -> void:
	enter_vr_btn.show()
	enter_vr_btn.disabled = false
	vr_status_label.text = "VR ready"
	vr_status_label.show()
