extends RefCounted
## Sprite-based accretion layers, inward dust streams and contracting light ripples.
const ART = preload("res://scripts/game_art.gd")
const DUST_COUNT: int = 64
const ORBIT_COUNT: int = 16

static func dust_point(index: int, clock: float) -> Vector2:
    var progress: float = fposmod(clock * 0.38 + float(index) / DUST_COUNT, 1.0)
    var angle: float = index * 2.399963 + clock * 0.55 + progress * 7.0
    var radius: float = lerpf(154, 25, progress * progress)
    return Vector2.from_angle(angle) * radius

static func draw(canvas: CanvasItem, center: Vector2, clock: float, proximity: float) -> void:
    var pulse: float = 1.0 + sin(clock * 4.3) * 0.055
    var strength: float = 0.75 + proximity * 0.5
    ART.effect(canvas, ART.Effect.GLOW, Rect2(center - Vector2.ONE * 98, Vector2.ONE * 196), Color(0.5, 0.1, 0.9, 0.2 * strength))
    # Outer and inner textured disks counter-rotate, with different pulse phases.
    canvas.draw_set_transform(center, -clock * 0.72, Vector2.ONE * (1 + sin(clock * 3.1) * 0.035))
    ART.hazard(canvas, ART.Hazard.BLACK_HOLE, Rect2(-63, -63, 126, 126), Color(0.85, 0.55, 1, 0.32 * strength))
    canvas.draw_set_transform(center, clock * 1.45, Vector2.ONE * pulse)
    ART.hazard(canvas, ART.Hazard.BLACK_HOLE, Rect2(-54, -54, 108, 108))
    canvas.draw_set_transform(Vector2.ZERO)
    # Pale lensing ripples contract rather than expanding like explosion shockwaves.
    for ripple in range(3):
        var progress: float = fposmod(clock * 0.48 + ripple / 3.0, 1)
        var radius: float = lerpf(99, 31, progress)
        var opacity: float = sin(progress * PI) * 0.22 * strength
        ART.effect(canvas, ART.Effect.RING, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), Color(0.7, 0.35, 1, opacity))
    for index in range(DUST_COUNT):
        var progress: float = fposmod(clock * 0.38 + float(index) / DUST_COUNT, 1)
        var point: Vector2 = center + dust_point(index, clock)
        # Avoid a streak across the field when a particle starts a new orbit.
        var tail_clock: float = clock - minf(0.035, progress / 0.38)
        var tail: Vector2 = center + dust_point(index, tail_clock)
        var opacity: float = sin(progress * PI) * strength
        var color: Color = Color("ce88ff").lerp(Color("ffd4ae"), progress * progress)
        ART.streak(canvas, tail, point, 2.0 + progress * 1.5, Color(color, opacity * 0.7))
        ART.effect(canvas, ART.Effect.SPARK, Rect2(point - Vector2.ONE * 2.5, Vector2.ONE * 5), Color(color, opacity))
    # Hot flecks race around the event-horizon edge, visibly faster than the disk.
    for index in range(ORBIT_COUNT):
        var angle: float = index * TAU / ORBIT_COUNT + clock * 2.6
        var radius: float = 34 + sin(clock * 5 + index) * 2
        var point: Vector2 = center + Vector2.from_angle(angle) * radius
        ART.effect(canvas, ART.Effect.SPARK, Rect2(point - Vector2.ONE * 3, Vector2.ONE * 6), Color(1, 0.65, 0.95, (0.45 + sin(clock * 7 + index) * 0.2) * strength))
