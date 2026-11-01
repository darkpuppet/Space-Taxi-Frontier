extends Node2D
const ART = preload("res://scripts/game_art.gd")
## Bounded analytic particles: deterministic motion without accumulating emitters.
const VORTEX_COUNT: int = 96
const RIM_COUNT: int = 48
var age: float = 0.0
var approach: float = 0.0
var energy: Node2D

func _ready() -> void:
    z_index = 3
    energy = Node2D.new()
    var additive := CanvasItemMaterial.new()
    additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    energy.material = additive
    add_child(energy)
    energy.draw.connect(_draw_energy)

func activate(center: Vector2) -> void:
    position = center
    age = 0.0
    visible = true
    queue_redraw()
    energy.queue_redraw()

func advance(dt: float, ship_position: Vector2) -> void:
    age += maxf(0, dt)
    approach = 1.0 - smoothstep(70, 300, ship_position.distance_to(position))
    queue_redraw()
    energy.queue_redraw()

func vortex_point(index: int, offset: float = 0.0) -> Vector2:
    var progress: float = clampf(fposmod(age * 0.42 + float(index) / VORTEX_COUNT, 1.0) + offset, 0, 1)
    var angle: float = index * 2.399963 + age * 0.6 + progress * 5.8
    return Vector2.from_angle(angle) * lerpf(102, 5, progress * progress)

func _draw() -> void:
    ART.hazard(self, ART.Hazard.STAR_GATE, Rect2(-66, -66, 132, 132))
    draw_string(ThemeDB.fallback_font, Vector2(-44, 108), "STAR GATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a5f8ff"))

func _draw_energy() -> void:
    var power: float = 0.8 + approach * 0.35
    for ring in range(6, 0, -1):
        var radius: float = 48 + ring * 7
        ART.effect(energy, ART.Effect.GLOW, Rect2(-Vector2.ONE * radius, Vector2.ONE * radius * 2), Color(0.1, 0.45, 0.8, 0.06 * power))
    # Three curling filaments form an animated vortex behind the flowing motes.
    for arm in range(3):
        var points := PackedVector2Array()
        for step in range(55):
            var t: float = float(step) / 54
            var angle: float = arm * TAU / 3 + age * 0.9 + t * 6
            points.append(Vector2.from_angle(angle) * lerpf(47, 4, t))
        energy.draw_polyline(points, Color(0.2, 0.45, 1, 0.13 * power), 5, true)
        energy.draw_polyline(points, Color(0.3, 0.85, 1, 0.25 * power), 1, true)
    for index in range(VORTEX_COUNT):
        var point: Vector2 = vortex_point(index)
        var progress: float = fposmod(age * 0.42 + float(index) / VORTEX_COUNT, 1)
        var alpha: float = sin(progress * PI) * power
        var color: Color = Color("64e9ff").lerp(Color("c09aff"), float(index % 5) / 4)
        ART.streak(energy, vortex_point(index, -0.025), point, 3, Color(color, alpha * 0.6))
        ART.effect(energy, ART.Effect.GLOW, Rect2(point - Vector2.ONE * 5, Vector2.ONE * 10), Color(color, alpha * 0.12))
        ART.effect(energy, ART.Effect.SPARK, Rect2(point - Vector2.ONE * 3, Vector2.ONE * 6), Color(color, alpha * 0.8))
    # Counter-rotating broken rings and small electrical diamonds on the rim.
    for ring in range(2):
        for segment in range(8):
            var angle: float = segment * TAU / 8 + age * (0.42 if ring == 0 else -0.3)
            var color := Color(0.25, 0.9, 1, 0.75) if ring == 0 else Color(0.55, 0.35, 1, 0.6)
            var radius: float = 53 + ring * 8
            energy.draw_arc(Vector2.ZERO, radius, angle, angle + 0.52, 18, Color(color, 0.1), 8, true)
            energy.draw_arc(Vector2.ZERO, radius, angle, angle + 0.52, 18, color, 2, true)
    for index in range(RIM_COUNT):
        var angle: float = float(index) / RIM_COUNT * TAU - age * 0.5
        var flutter: float = fposmod(age * 0.7 + index * 0.618, 1)
        var point := Vector2.from_angle(angle) * (57 + flutter * 15)
        var alpha: float = (1 - flutter) * power
        ART.streak(energy, point, point + Vector2.from_angle(angle + PI * 0.5) * 5, 3, Color(0.65, 0.9, 1, alpha))
    for glyph in range(10):
        var angle: float = glyph * TAU / 10 + age * 0.16
        var point := Vector2.from_angle(angle) * 76
        ART.effect(energy, ART.Effect.SPARK, Rect2(point - Vector2.ONE * 4, Vector2.ONE * 8), Color(0.4, 0.75, 1, 0.3 + approach * 0.2))
    var opening: float = maxf(0, 1.0 - age / 0.8)
    var opening_radius: float = 20 + age * 160
    ART.effect(energy, ART.Effect.RING, Rect2(-Vector2.ONE * opening_radius, Vector2.ONE * opening_radius * 2), Color(0.5, 0.9, 1, opening * 0.8))
    var pulse: float = 0.5 + sin(age * 4) * 0.12 + approach * 0.2
    ART.effect(energy, ART.Effect.GLOW, Rect2(-11, -11, 22, 22), Color(0.3, 0.55, 1, pulse * 0.35))
    ART.effect(energy, ART.Effect.SPARK, Rect2(-4, -4, 8, 8), Color(0.7, 0.95, 1, pulse))
