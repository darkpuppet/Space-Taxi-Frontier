extends Control

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    resized.connect(queue_redraw)

func _draw() -> void:
    var middle: float = size.x * 0.5
    var y: float = size.y + 3
    var gold := Color("dcb779")
    for side in [-1, 1]:
        draw_line(Vector2(middle + side * 14, y), Vector2(middle + side * minf(145, middle - 4), y), gold, 1, true)
        draw_line(Vector2(middle + side * 26, y + 3), Vector2(middle + side * minf(120, middle - 4), y + 3), Color(gold, 0.45), 1, true)
    draw_polyline(PackedVector2Array([Vector2(middle, y - 4), Vector2(middle + 6, y), Vector2(middle, y + 4), Vector2(middle - 6, y), Vector2(middle, y - 4)]), gold, 1, true)
