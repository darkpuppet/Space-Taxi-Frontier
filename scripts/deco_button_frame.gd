extends Control
var compact: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    resized.connect(queue_redraw)
    var button: Button = get_parent()
    for event in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited, button.button_down, button.button_up]:
        event.connect(queue_redraw)

func _draw() -> void:
    var button: Button = get_parent()
    var color := Color("f2cc83")
    if button.has_focus(): color = Color("8ef0df")
    if button.disabled: color = Color("6a716f")
    var inset: float = 4.0
    var step: float = 4.0 if compact else 7.0
    var left: float = inset
    var right: float = size.x - inset
    var top: float = inset
    var bottom: float = size.y - inset
    var outline := PackedVector2Array([
        Vector2(left + step, top), Vector2(right - step, top),
        Vector2(right - step, top + step), Vector2(right, top + step),
        Vector2(right, bottom - step), Vector2(right - step, bottom - step),
        Vector2(right - step, bottom), Vector2(left + step, bottom),
        Vector2(left + step, bottom - step), Vector2(left, bottom - step),
        Vector2(left, top + step), Vector2(left + step, top + step), Vector2(left + step, top)])
    draw_polyline(outline, Color(color, 0.72), 1, true)
    if not compact and size.x > 140:
        for x in [14.0, size.x - 14]:
            var center := Vector2(x, size.y * 0.5)
            draw_colored_polygon(PackedVector2Array([center + Vector2(0,-3), center + Vector2(2,0), center + Vector2(0,3), center + Vector2(-2,0)]), color)
