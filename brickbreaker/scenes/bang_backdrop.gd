extends Control

func _ready() -> void:
    queue_redraw()


func _draw() -> void:
    var center := size * 0.5
    var spikes := 14
    var outer := minf(size.x, size.y) * 0.5
    var inner := outer * 0.42
    var points := PackedVector2Array()
    for i in spikes * 2:
        var angle := (TAU / float(spikes * 2)) * float(i) - PI * 0.5
        var r := outer if i % 2 == 0 else inner
        points.append(center + Vector2(cos(angle), sin(angle)) * r)
    draw_colored_polygon(points, Color(1.0, 0.92, 0.2, 0.95))
    for i in spikes * 2:
        var angle := (TAU / float(spikes * 2)) * float(i) - PI * 0.5
        var r := outer * 1.05 if i % 2 == 0 else inner * 0.9
        var next_i := (i + 1) % (spikes * 2)
        var angle2 := (TAU / float(spikes * 2)) * float(next_i) - PI * 0.5
        var r2 := outer * 1.05 if next_i % 2 == 0 else inner * 0.9
        draw_line(
            center + Vector2(cos(angle), sin(angle)) * r,
            center + Vector2(cos(angle2), sin(angle2)) * r2,
            Color(0.85, 0.12, 0.1, 1.0),
            3.0,
        )
