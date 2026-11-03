extends RefCounted
## Sprite-only scenery: deliberately absent from physics, navigation and radar.
const ATLAS: Texture2D = preload("res://assets/sprites/frontier-background-traffic-v2.png")
const COMET_ATLAS: Texture2D = preload("res://assets/sprites/frontier-comets-v1.png")
const COMET_VARIANTS: int = 4
const WORLD = preload("res://scripts/world.gd")
const STAR_COUNT: int = 72
const MAX_PASSERS: int = 3
var rng := RandomNumberGenerator.new()
var stars: Array[Dictionary] = []
var passers: Array[Dictionary] = []
var clock: float = 0.0
var countdown: float = 0.0
var next_kind: int = 1
var last_comet_variant: int = -1

func configure(level: int) -> void:
    rng.randomize()
    stars.clear()
    passers.clear()
    clock = 0.0
    countdown = rng.randf_range(4, 8)
    next_kind = 1 + level % 3
    last_comet_variant = -1
    for index in range(STAR_COUNT):
        stars.append({
            "position": Vector2(rng.randf_range(30, WORLD.WIDTH - 30), rng.randf_range(150, WORLD.FLOOR - 60)),
            "size": rng.randf_range(5, 15),
            "phase": rng.randf_range(0, 4),
            "speed": rng.randf_range(0.7, 1.8)
        })

func advance(dt: float) -> void:
    clock += dt
    for index in range(passers.size() - 1, -1, -1):
        var passer: Dictionary = passers[index]
        passer["position"] += passer["velocity"] * dt
        passer["age"] += dt
        var point: Vector2 = passer["position"]
        if point.x < -220 or point.x > WORLD.WIDTH + 220 or point.y < -220 or point.y > WORLD.HEIGHT + 220 or float(passer["age"]) > 75:
            passers.remove_at(index)
    countdown -= dt
    if countdown <= 0:
        if passers.size() < MAX_PASSERS:
            _spawn(next_kind)
            next_kind = 1 + next_kind % 3
        countdown = rng.randf_range(10, 18)

func _spawn(kind: int) -> void:
    var direction: float = -1.0 if rng.randf() < 0.5 else 1.0
    var speed: float = rng.randf_range(100, 145) if kind == 1 else rng.randf_range(45, 70)
    if kind == 3:
        speed = rng.randf_range(35, 55)
    var comet_variant: int = -1
    if kind == 1:
        comet_variant = rng.randi_range(0, COMET_VARIANTS - 1) if last_comet_variant < 0 else (last_comet_variant + rng.randi_range(1, COMET_VARIANTS - 1)) % COMET_VARIANTS
        last_comet_variant = comet_variant
    passers.append({
        "kind": kind,
        "comet_variant": comet_variant,
        "position": Vector2(-160 if direction > 0 else WORLD.WIDTH + 160, rng.randf_range(220, WORLD.FLOOR - 250)),
        "velocity": Vector2(speed * direction, rng.randf_range(-6, 6)),
        "age": 0.0,
        "phase": rng.randf_range(0, 4),
        "scale": rng.randf_range(0.65, 1.0),
        "direction": direction
    })

func paint(canvas: CanvasItem) -> void:
    # Derive cells from the original PNG dimensions; preserve generated artwork.
    var cell: Vector2 = ATLAS.get_size() / 4.0
    for star in stars:
        var frame: int = int(clock * float(star["speed"]) + float(star["phase"])) % 4
        var size: float = float(star["size"])
        var point: Vector2 = star["position"]
        var star_side: float = minf(cell.x, cell.y)
        var star_region := Rect2(Vector2(frame * cell.x + (cell.x - star_side) * 0.5, (cell.y - star_side) * 0.5), Vector2.ONE * star_side)
        canvas.draw_texture_rect_region(ATLAS, Rect2(point - Vector2.ONE * size * 0.5, Vector2.ONE * size), star_region, Color(0.8, 0.9, 1, 0.65))
    for passer in passers:
        var kind: int = int(passer["kind"])
        var frame: int = int(float(passer["age"]) * (8 if kind != 3 else 2) + float(passer["phase"])) % 4
        var size := Vector2(128, 64) * float(passer["scale"])
        var point: Vector2 = passer["position"]
        var rect := Rect2(point - size * 0.5, size)
        if float(passer["direction"]) < 0:
            rect.position.x += rect.size.x
            rect.size.x = -rect.size.x
        var texture: Texture2D = ATLAS
        var region := Rect2(Vector2(frame, kind) * cell, cell)
        var comet_variant: int = int(passer.get("comet_variant", 0))
        if kind == 1 and comet_variant > 0:
            texture = COMET_ATLAS
            var comet_cell: Vector2 = COMET_ATLAS.get_size() / Vector2(4, 3)
            region = Rect2(Vector2(frame, comet_variant - 1) * comet_cell, comet_cell)
        canvas.draw_texture_rect_region(texture, rect, region, Color(0.85, 0.9, 1, 0.65))
