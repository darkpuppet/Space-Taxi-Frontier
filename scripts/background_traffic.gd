extends RefCounted
## Sprite-only scenery: deliberately absent from physics, navigation and radar.
const ATLAS: Texture2D = preload("res://assets/sprites/frontier-background-traffic-v2.png")
const COMET_ATLAS: Texture2D = preload("res://assets/sprites/frontier-comets-v1.png")
const COMET_VARIANTS: int = 4
const WORLD = preload("res://scripts/world.gd")
const STAR_COUNT: int = 72
const MAX_PASSERS: int = 3
# Normalized open-sky areas authored against each background PNG. Keep clear
# of painted terrain, planets, station frames and floating land masses.
const SKY_REGIONS: Array[Rect2] = [
    Rect2(0.15, 0.10, 0.55, 0.29), # Observation window, above the planet.
    Rect2(0.14, 0.03, 0.65, 0.42), # Desert, between the moons.
    Rect2(0.25, 0.03, 0.50, 0.47), # Ice, clear of spires and planets.
    Rect2(0.25, 0.03, 0.48, 0.47), # Copper canyon.
    Rect2(0.34, 0.04, 0.28, 0.45), # Between the fungal canopies and moons.
    Rect2(0.28, 0.03, 0.50, 0.43), # Above the neon skyline.
    Rect2(0.40, 0.03, 0.35, 0.46), # Between the twin suns.
    Rect2(0.25, 0.03, 0.42, 0.46), # Inside the hive's open canopy.
    Rect2(0.08, 0.03, 0.35, 0.37), # Clear of the ringed planet.
    Rect2(0.18, 0.03, 0.37, 0.48), # Left of the orbital wheel.
    Rect2(0.12, 0.03, 0.78, 0.40), # Above the binary sunset.
    Rect2(0.30, 0.03, 0.31, 0.19), # Above the asteroid belt.
    Rect2(0.40, 0.38, 0.25, 0.25), # Below the rift's floating rock stream.
    Rect2(0.30, 0.03, 0.41, 0.45), # Above the volcanic horizon.
    Rect2(0.33, 0.04, 0.28, 0.40), # Between floating gardens and planets.
    Rect2(0.15, 0.03, 0.70, 0.42), # Above the ocean and moon.
    Rect2(0.28, 0.03, 0.40, 0.45), # Between the nebula's rock fields.
    Rect2(0.40, 0.04, 0.22, 0.40), # Inside the derelict station opening.
    Rect2(0.30, 0.04, 0.31, 0.49), # Clear of the eclipse and canyon.
    Rect2(0.18, 0.03, 0.44, 0.40), # Left of the frontier gateway.
]
var sky_region: Rect2
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
    var normalized: Rect2 = SKY_REGIONS[clampi(level, 0, SKY_REGIONS.size() - 1)]
    var world_size := Vector2(WORLD.WIDTH, WORLD.HEIGHT)
    sky_region = Rect2(normalized.position * world_size, normalized.size * world_size)
    for index in range(STAR_COUNT):
        var size: float = rng.randf_range(5, 15)
        # Include the entire twinkle/glow footprint, with a little sky padding.
        var safe_centers: Rect2 = sky_region.grow(-size * 0.5 - 8.0)
        stars.append({
            "position": Vector2(rng.randf_range(safe_centers.position.x, safe_centers.end.x), rng.randf_range(safe_centers.position.y, safe_centers.end.y)),
            "size": size,
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
    var position := Vector2(-160 if direction > 0 else WORLD.WIDTH + 160, rng.randf_range(220, WORLD.FLOOR - 250))
    var velocity := Vector2(speed * direction, rng.randf_range(-6, 6))
    if kind in [1, 2]:
        var pitch: float = deg_to_rad(rng.randf_range(12.0, 35.0)) * (-1.0 if rng.randf() < 0.5 else 1.0)
        velocity = Vector2(cos(pitch) * direction, sin(pitch)) * speed
        # Trace back from an interior waypoint to an offscreen entry edge.
        # This keeps diagonal visitors crossing the world rather than missing it.
        var waypoint := Vector2(rng.randf_range(400, WORLD.WIDTH - 400), rng.randf_range(250, WORLD.HEIGHT - 250))
        var back_x: float = (waypoint.x + 160.0) / velocity.x if velocity.x > 0.0 else (WORLD.WIDTH + 160.0 - waypoint.x) / -velocity.x
        var back_y: float = (waypoint.y + 160.0) / velocity.y if velocity.y > 0.0 else (WORLD.HEIGHT + 160.0 - waypoint.y) / -velocity.y
        position = waypoint - velocity * minf(back_x, back_y)
    var comet_variant: int = -1
    if kind == 1:
        comet_variant = rng.randi_range(0, COMET_VARIANTS - 1) if last_comet_variant < 0 else (last_comet_variant + rng.randi_range(1, COMET_VARIANTS - 1)) % COMET_VARIANTS
        last_comet_variant = comet_variant
    passers.append({
        "kind": kind,
        "comet_variant": comet_variant,
        "position": position,
        "velocity": velocity,
        "age": 0.0,
        "phase": rng.randf_range(0, 4),
        "scale": rng.randf_range(0.65, 1.0),
        "direction": direction
    })

func passer_transform(passer: Dictionary) -> Transform2D:
    var direction: float = float(passer["direction"])
    var pitch: float = 0.0
    if int(passer["kind"]) in [1, 2]:
        var velocity: Vector2 = passer["velocity"]
        direction = -1.0 if velocity.x < 0.0 else 1.0
        pitch = atan2(velocity.y * direction, absf(velocity.x))
    # The atlas heads point right. Mirror leftward traffic while keeping ships
    # upright, then rotate so every comet's tail trails its actual velocity.
    return Transform2D(Vector2(cos(pitch), sin(pitch)) * direction, Vector2(-sin(pitch), cos(pitch)), Vector2(passer["position"]))

func paint_stars(canvas: CanvasItem) -> void:
    # Derive cells from the original PNG dimensions; preserve generated artwork.
    var cell: Vector2 = ATLAS.get_size() / 4.0
    for star in stars:
        var frame: int = int(clock * float(star["speed"]) + float(star["phase"])) % 4
        var size: float = float(star["size"])
        var point: Vector2 = star["position"]
        var star_side: float = minf(cell.x, cell.y)
        var star_region := Rect2(Vector2(frame * cell.x + (cell.x - star_side) * 0.5, (cell.y - star_side) * 0.5), Vector2.ONE * star_side)
        canvas.draw_texture_rect_region(ATLAS, Rect2(point - Vector2.ONE * size * 0.5, Vector2.ONE * size), star_region, Color(0.8, 0.9, 1, 0.65))

func paint_passers(canvas: CanvasItem) -> void:
    var cell: Vector2 = ATLAS.get_size() / 4.0
    for passer in passers:
        var kind: int = int(passer["kind"])
        var frame: int = int(float(passer["age"]) * (8 if kind != 3 else 2) + float(passer["phase"])) % 4
        var size := Vector2(128, 64) * float(passer["scale"])
        var rect := Rect2(-size * 0.5, size)
        var texture: Texture2D = ATLAS
        var region := Rect2(Vector2(frame, kind) * cell, cell)
        var comet_variant: int = int(passer.get("comet_variant", 0))
        if kind == 1 and comet_variant > 0:
            texture = COMET_ATLAS
            var comet_cell: Vector2 = COMET_ATLAS.get_size() / Vector2(4, 3)
            region = Rect2(Vector2(frame, comet_variant - 1) * comet_cell, comet_cell)
        canvas.draw_set_transform_matrix(passer_transform(passer))
        canvas.draw_texture_rect_region(texture, rect, region, Color(0.85, 0.9, 1, 0.65))
        canvas.draw_set_transform(Vector2.ZERO)
