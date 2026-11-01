extends RefCounted
## Dedicated workshop artwork, with a flat landing surface at the authored y.
const ART: Texture2D = preload("res://assets/sprites/frontier-upgrade-dock-v1.png")
const CYAN := Color("73f4ee")
const VIOLET := Color("c896ff")
static var texture: AtlasTexture

static func draw(canvas: CanvasItem, pad: Dictionary, clock: float) -> void:
    if texture == null:
        var image: Image = ART.get_image()
        var minimum := Vector2i(image.get_width(), image.get_height())
        var maximum := Vector2i.ZERO
        for y in range(image.get_height()):
            for x in range(image.get_width()):
                if image.get_pixel(x, y).a >= 0.25:
                    minimum.x = mini(minimum.x, x)
                    minimum.y = mini(minimum.y, y)
                    maximum.x = maxi(maximum.x, x)
                    maximum.y = maxi(maximum.y, y)
        texture = AtlasTexture.new()
        texture.atlas = ART
        texture.region = Rect2(minimum, maximum - minimum + Vector2i.ONE)
        texture.filter_clip = true
    var width: float = float(pad["width"])
    var center := Vector2(float(pad["x"]), float(pad["y"]))
    var left: float = center.x - width * 0.5
    canvas.draw_texture_rect(texture, Rect2(left, center.y, width, 42), false)
    canvas.draw_line(Vector2(left + 4, center.y), Vector2(left + width - 4, center.y), CYAN, 3, true)
    # Animated inward guide lights make the workshop identifiable at a glance.
    for side in [-1, 1]:
        for step in range(3):
            var x: float = center.x + side * (width * 0.5 - 12 - step * 8)
            var opacity: float = 0.35 + 0.65 * maxf(0, sin(clock * 4 - step * 1.2))
            var points := PackedVector2Array([Vector2(x + side * 3, center.y + 8), Vector2(x, center.y + 12), Vector2(x + side * 3, center.y + 16)])
            canvas.draw_polyline(points, Color(0.45, 1, 0.95, opacity), 2, true)
    var sign_width: float = maxf(140, width * 0.85)
    var sign := Rect2(center + Vector2(-sign_width * 0.5, 46), Vector2(sign_width, 42))
    canvas.draw_rect(sign, Color("211636f2"))
    canvas.draw_rect(sign, VIOLET, false, 1.5)
    var title: String = "02 / UPGRADES"
    var font: Font = ThemeDB.fallback_font
    var title_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
    canvas.draw_string(font, Vector2(center.x - title_width * 0.5, center.y + 63), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CYAN)
    var subtitle: String = "FUEL + REPAIR"
    var subtitle_width: float = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
    canvas.draw_string(font, Vector2(center.x - subtitle_width * 0.5, center.y + 79), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, VIOLET)
