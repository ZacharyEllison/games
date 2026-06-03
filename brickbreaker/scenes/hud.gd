extends CanvasLayer

@onready var score_label: Label = $Score
@onready var lives_label: Label = $Lives
@onready var message: Label = $Message

func set_score(value: int) -> void:
	score_label.text = "SCORE %d" % value
	_bump(score_label)

func set_lives(value: int) -> void:
	lives_label.text = "LIVES %d" % value
	_bump(lives_label)

func show_message(text: String) -> void:
	message.text = text
	message.show()
	message.scale = Vector2(0.4, 0.4)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(message, "scale", Vector2.ONE, 0.3)

func hide_message() -> void:
	message.hide()

func _bump(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(1.3, 1.3)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.25)
