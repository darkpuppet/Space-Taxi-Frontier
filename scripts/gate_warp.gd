extends CanvasLayer
const ART = preload("res://scripts/game_art.gd")
## Brief warp streaks survive the instant level change, including the final gate.
const DURATION: float = 0.42
var age: float = DURATION
var canvas: Node2D

func _ready() -> void:
    layer = 4
    canvas = Node2D.new()
    add_child(canvas)
    canvas.draw.connect(_draw_warp)

func trigger() -> void:
    age = 0.0
    canvas.queue_redraw()

func advance(dt: float) -> void:
    if age < DURATION:
        age = minf(DURATION, age + maxf(0, dt))
        canvas.queue_redraw()

func _draw_warp() -> void:
    if age >= DURATION:
        return
    var size: Vector2 = canvas.get_viewport_rect().size
    var center: Vector2 = size * 0.5
    var t: float = age / DURATION
    var fade: float = pow(1.0 - t, 2)
    canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.9, 1, fade * 0.22))
    for index in range(56):
        var direction := Vector2.from_angle(index * 2.399963)
        var distance: float = 70 + t * (350 + index % 7 * 45)
        var start: Vector2 = center + direction * distance
        var finish: Vector2 = start + direction * (20 + t * 100)
        ART.streak(canvas, start, finish, 3.0 + index % 3, Color(0.65, 0.9, 1, fade * 0.7))
    var radius: float = 45 + t * 500
    ART.effect(canvas, ART.Effect.RING, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), Color(0.6, 0.85, 1, fade * 0.7))
