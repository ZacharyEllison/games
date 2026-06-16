class_name HUD
extends CanvasLayer

signal reset_requested
signal enter_vr_requested

@onready var enter_vr_btn: Button = %EnterVRBtn
@onready var vr_status_label: Label = %VRStatusLabel
@onready var reset_btn: Button = %ResetBtn
@onready var desktop_hint: Label = %DesktopHint

func _ready() -> void:
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
