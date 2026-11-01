extends RefCounted
const ART = preload("res://scripts/game_art.gd")
const ATLAS: Texture2D = preload("res://assets/sprites/frontier-accidents-v1.png")
static var frames: Array[Texture2D] = []

static func prepare() -> void:
    if frames.is_empty():
        frames = ART.slice(ATLAS, 2, [0.0, 0.5, 1.0], 0.15)

static func draw(canvas: CanvasItem, accident: Dictionary) -> void:
    prepare()
    var point: Vector2 = accident["position"]
    var age: float = float(accident["age"])
    var color: Color = accident["color"]
    var splash: float = maxf(0, 1 - age / 0.32)
    var radius: float = 10 + age * 65
    if splash > 0:
        canvas.draw_texture_rect(frames[3], Rect2(point - Vector2(radius, radius * 1.1), Vector2.ONE * radius * 2), false, Color(color, splash))
    var stain: float = 1.0 - smoothstep(0.6, 1.4, age)
    if stain > 0:
        canvas.draw_texture_rect(frames[1 if accident["alien"] else 0], Rect2(point + Vector2(-14, -3), Vector2(28, 7)), false, Color(1, 1, 1, stain))
    if age >= 0.25:
        var rise: float = smoothstep(0.25, 0.45, age)
        canvas.draw_texture_rect(frames[2], Rect2(point + Vector2(-11, -30 * rise), Vector2(22, 30 * rise)), false)
    var fine_fade: float = 1.0 - smoothstep(0.6, 1.4, age)
    if fine_fade > 0:
        canvas.draw_string(ThemeDB.fallback_font, point + Vector2(-28, -39 - age * 8), "-250 CR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.65, 0.45, fine_fade))
