class_name ConfettiEffect
extends RefCounted

const COLORS := [
    Color("#a3be8c"),
    Color("#ebcb8b"),
    Color("#88c0d0"),
    Color("#bf616a"),
    Color("#d08770"),
    Color("#b48ead"),
]


static func burst(parent: Control, origin: Vector2, count: int = 64) -> void:
    var layer := Control.new()
    layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(layer)

    for i in range(count):
        var piece := ColorRect.new()
        piece.custom_minimum_size = Vector2(8, 14) * randf_range(0.7, 1.35)
        piece.size = piece.custom_minimum_size
        piece.pivot_offset = piece.size * 0.5
        piece.color = COLORS[randi() % COLORS.size()]
        piece.rotation = deg_to_rad(randf_range(0.0, 360.0))
        piece.global_position = origin + Vector2(randf_range(-24.0, 24.0), randf_range(-12.0, 12.0))
        layer.add_child(piece)

        var velocity := Vector2(randf_range(-260.0, 260.0), randf_range(-420.0, -180.0))
        var gravity := 980.0
        var duration := randf_range(0.9, 1.45)
        var tween := layer.create_tween()
        tween.set_parallel(true)
        tween.tween_property(piece, "global_position:x", piece.global_position.x + velocity.x * duration, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.tween_property(piece, "global_position:y", piece.global_position.y + velocity.y * duration + 0.5 * gravity * duration * duration, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.tween_property(piece, "rotation", piece.rotation + deg_to_rad(randf_range(-540.0, 540.0)), duration)
        tween.tween_property(piece, "modulate:a", 0.0, duration * 0.85).set_delay(duration * 0.15)

    var cleanup := layer.create_tween()
    cleanup.tween_interval(1.6)
    cleanup.tween_callback(layer.queue_free)
