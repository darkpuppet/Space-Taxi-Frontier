extends Node2D
## World-space rainfall; inherited sector processing freezes it during pause.
var elapsed: float = 0.0
var foreground: bool = false
var drops: Array[Vector2] = []
var coverage := Vector2.ZERO

func configure(world_size: Vector2, near_view: bool) -> void:
    foreground = near_view
    coverage = world_size + Vector2(384, 384)
    var rng := RandomNumberGenerator.new()
    rng.seed = 6061 if foreground else 6060
    drops.clear()
    for index in range(260 if foreground else 520):
        drops.append(Vector2(rng.randf() * coverage.x, rng.randf() * coverage.y))
    queue_redraw()

func _process(dt: float) -> void:
    elapsed += dt
    queue_redraw()

func _draw() -> void:
    var speed: float = 820.0 if foreground else 460.0
    var streak := Vector2(-7, 34) if foreground else Vector2(-3, 17)
    var tint := Color(0.57, 0.76, 1.0, 0.25 if foreground else 0.17)
    for drop in drops:
        var point := Vector2(fposmod(drop.x - elapsed * speed * 0.20, coverage.x), fposmod(drop.y + elapsed * speed, coverage.y)) - Vector2(192, 192)
        draw_line(point, point + streak, tint, 1.6 if foreground else 0.8, true)
