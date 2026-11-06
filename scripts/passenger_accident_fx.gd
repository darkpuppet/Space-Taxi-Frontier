extends RefCounted
const ART = preload("res://scripts/game_art.gd")
const ATLAS: Texture2D = preload("res://assets/sprites/frontier-accidents-v1.png")
const DISSOLVE_DURATION: float = 0.9
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
        if accident.has("dissolve_age"):
            _dissolving_grave(canvas, point, float(accident["dissolve_age"]))
        else:
            canvas.draw_texture_rect(frames[2], Rect2(point + Vector2(-11, -30 * rise), Vector2(22, 30 * rise)), false)
    var fine_fade: float = 1.0 - smoothstep(0.6, 1.4, age)
    if fine_fade > 0:
        canvas.draw_string(ThemeDB.fallback_font, point + Vector2(-28, -39 - age * 8), "-₡250", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.65, 0.45, fine_fade))

## Sink the original sprite through the surface while small textured pieces fade.
## Source regions are clipped at the ground, so the grave never draws below it.
static func _dissolving_grave(canvas: CanvasItem, point: Vector2, age: float) -> void:
    var progress: float = clampf(age / DISSOLVE_DURATION, 0, 1)
    if progress >= 1:
        return
    var sink: float = smoothstep(0, 1, progress) * 30.0
    var texture: Texture2D = frames[2]
    var source_size: Vector2 = texture.get_size()
    for row in range(10):
        var top: float = -30.0 + row * 3.0 + sink
        if top >= 0:
            continue
        var height: float = minf(3.0, -top)
        for column in range(6):
            var grain: float = float(posmod(row * 37 + column * 53, 101)) / 100.0
            var fade: float = 1.0 - smoothstep(0.15 + grain * 0.4, 0.55 + grain * 0.45, progress)
            if fade <= 0:
                continue
            var destination := Rect2(point + Vector2(-11 + column * 22.0 / 6, top), Vector2(22.0 / 6, height))
            var source := Rect2(Vector2(column / 6.0, row / 10.0) * source_size, Vector2(1.0 / 6, height / 30.0) * source_size)
            canvas.draw_texture_rect_region(texture, destination, source, Color(1, 1, 1, fade))
    for grain in range(12):
        var fall: float = progress * 1.6 - grain * 0.055
        if fall <= 0 or fall >= 1:
            continue
        var drift: float = sin(grain * 2.4) * 2 * fall
        var center: Vector2 = point + Vector2(-12 + grain * 24.0 / 11 + drift, -8 * (1 - fall))
        var size: float = 2 + (1 - fall) * 2
        var alpha: float = sin(fall * PI) * (1 - progress) * 0.6
        ART.effect(canvas, ART.Effect.SMOKE, Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), Color(0.65, 0.73, 0.77, alpha))
