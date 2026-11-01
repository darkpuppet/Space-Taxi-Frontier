extends RefCounted
## Original Frontier credit mark: a chamfered C with twin currency strokes.
static func draw(canvas: CanvasItem, center: Vector2, height: float, color: Color) -> void:
    var scale: float = height / 16.0
    var outline := PackedVector2Array()
    for point in [Vector2(4,-4), Vector2(1,-6), Vector2(-3,-6), Vector2(-5,-3), Vector2(-5,3), Vector2(-3,6), Vector2(1,6), Vector2(4,4)]:
        outline.append(center + point * scale)
    canvas.draw_polyline(outline, color, maxf(1.0, scale * 1.3), true)
    for x in [-1.0, 1.5]:
        canvas.draw_line(center + Vector2(x, -8) * scale, center + Vector2(x, 8) * scale, color, maxf(1.0, scale), true)
