extends RefCounted
## Painted station sign with a live, font-independent seven-segment readout.
const ART: Texture2D = preload("res://assets/sprites/frontier-fuel-sign-v1.png")
# Bits run clockwise from the top bar, followed by the middle bar.
const DIGITS := [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f]
const LIT := Color("8fffe9")
const UNLIT := Color("102c30")

static func draw(canvas: CanvasItem, rect: Rect2, price: int) -> void:
    canvas.draw_texture_rect(ART, rect, false)
    # Register the digits with the blank window painted into the sign sprite.
    var digit_size: Vector2 = rect.size * Vector2(0.105, 0.165)
    var origin: Vector2 = rect.position + rect.size * Vector2(0.375, 0.355)
    var value: String = "%02d" % clampi(price, 0, 99)
    for index in range(2):
        _digit(canvas, Rect2(origin + Vector2(index * digit_size.x * 1.4, 0), digit_size), value.unicode_at(index) - 48)

static func _digit(canvas: CanvasItem, rect: Rect2, value: int) -> void:
    var bars := [Rect2(0.14, 0.0, 0.72, 0.10), Rect2(0.82, 0.08, 0.18, 0.38), Rect2(0.82, 0.54, 0.18, 0.38), Rect2(0.14, 0.90, 0.72, 0.10), Rect2(0.0, 0.54, 0.18, 0.38), Rect2(0.0, 0.08, 0.18, 0.38), Rect2(0.14, 0.45, 0.72, 0.10)]
    for index in range(7):
        var bar: Rect2 = bars[index]
        var points: PackedVector2Array
        if index in [0, 3, 6]:
            points = PackedVector2Array([Vector2(0, 0.5), Vector2(0.12, 0), Vector2(0.88, 0), Vector2(1, 0.5), Vector2(0.88, 1), Vector2(0.12, 1)])
        else:
            points = PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.12), Vector2(1, 0.88), Vector2(0.5, 1), Vector2(0, 0.88), Vector2(0, 0.12)])
        for point in range(points.size()):
            points[point] = rect.position + (bar.position + points[point] * bar.size) * rect.size
        canvas.draw_colored_polygon(points, LIT if DIGITS[value] & (1 << index) else UNLIT)
