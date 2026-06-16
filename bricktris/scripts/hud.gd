class_name HUD
extends CanvasLayer

signal brick_selected(type: String)
signal reset_requested
signal enter_vr_requested

@onready var brick_buttons: Array[Button] = []
@onready var enter_vr_btn: Button = %EnterVRBtn
@onready var vr_status_label: Label = %VRStatusLabel
@onready var reset_btn: Button = %ResetBtn
@onready var desktop_hint: Label = %DesktopHint

func _ready() -> void:
	var grid := %BrickGrid
	for child in grid.get_children():
		if child is Button:
			brick_buttons.append(child)
			child.pressed.connect(_on_brick_btn_pressed.bind(child))

	reset_btn.pressed.connect(func(): reset_requested.emit())
	enter_vr_btn.pressed.connect(func(): enter_vr_requested.emit())

	enter_vr_btn.disabled = true
	vr_status_label.text = "Checking VR support..."
	desktop_hint.hide()

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
			desktop_hint.text = "Desktop mode - click to place bricks"
			desktop_hint.show()

func on_xr_started() -> void:
	enter_vr_btn.hide()
	vr_status_label.hide()

func on_xr_ended() -> void:
	enter_vr_btn.show()
	enter_vr_btn.disabled = false
	vr_status_label.text = "VR ready"
	vr_status_label.show()

func _on_brick_btn_pressed(btn: Button) -> void:
	var type: String = btn.get_meta("type", "")
	if type.is_empty():
		return
	brick_selected.emit(type)
	for b in brick_buttons:
		b.button_pressed = false
	btn.button_pressed = true
