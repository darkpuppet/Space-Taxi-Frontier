extends Node2D
## One random raider at a time; all timing advances through the game's pause gate.
const SPRITES = preload("res://scripts/sprites.gd")
const FIRST_LEVEL: int = 12
const FINE: int = 300
signal passenger_abducted(fare: Dictionary)
signal raid_started(pad: int)
var rng := RandomNumberGenerator.new()
var game: Node
var enabled: bool = false
var countdown: float = 0.0
var state: String = "idle"
var age: float = 0.0
var clock: float = 0.0
var target: Dictionary = {}
var position_in_world := Vector2.ZERO
var foot := Vector2.ZERO
var hover := Vector2.ZERO
var direction: float = 1.0

func _ready() -> void:
    rng.randomize()
    z_index = 5

func configure(owner_game: Node) -> void:
    game = owner_game
    reset()
    enabled = game.level + 1 >= FIRST_LEVEL
    countdown = rng.randf_range(18.0, 28.0)

func reset() -> void:
    if not target.is_empty():
        target.erase("abducting")
    target = {}
    state = "idle"
    age = 0.0
    queue_redraw()

func advance(dt: float) -> void:
    if get_tree().paused:
        return
    if not enabled or game.mission_done or game.game_over or game.explosion_active or game.taxi.capture_active:
        reset()
        return
    clock += dt
    if state == "idle":
        countdown -= dt
        if countdown <= 0:
            _start_raid()
        return
    age += dt
    if state != "depart":
        var still_waiting: bool = false
        for fare in game.dispatcher.waiting:
            if int(fare["id"]) == int(target["id"]):
                still_waiting = true
                break
        # A successful pickup or expired/killed fare cancels the attempt. Landing
        # rescues a rider during the approach/hover, before the beam takes hold.
        if not still_waiting or (state != "lift" and game.taxi.landed_on == int(target["source"])):
            _depart()
    match state:
        "approach":
            position_in_world = position_in_world.move_toward(hover, 280.0 * dt)
            if position_in_world.distance_to(hover) < 1:
                state = "hover"
                age = 0.0
        "hover":
            if age >= 2.5:
                var pad: Dictionary = game.pads[int(target["source"]) - 1]
                var walk: Dictionary = game.passenger_walk.get(int(target["id"]), {})
                foot = Vector2(float(walk.get("x", game._fare_home_x(pad))), float(pad["y"]) - 2)
                target["abducting"] = true
                state = "lift"
                age = 0.0
                game._sync_dispatch()
        "lift":
            if age >= 3.2:
                if game.dispatcher.abduct(int(target["id"])):
                    passenger_abducted.emit(target)
                _depart()
        "depart":
            position_in_world += Vector2(direction * (240.0 + age * 200.0), -100.0 - age * 80.0) * dt
            if age > 3.5:
                reset()
                countdown = rng.randf_range(22.0, 38.0)
    queue_redraw()

func _start_raid() -> void:
    var candidates: Array[Dictionary] = []
    for fare in game.dispatcher.waiting:
        if int(fare["source"]) != game.taxi.landed_on and not fare.get("abducting", false):
            candidates.append(fare)
    if candidates.is_empty():
        countdown = 4.0
        return
    target = candidates[rng.randi_range(0, candidates.size() - 1)]
    var pad: Dictionary = game.pads[int(target["source"]) - 1]
    foot = Vector2(game._fare_home_x(pad), float(pad["y"]) - 2)
    hover = foot + Vector2(0, -155)
    direction = 1.0 if rng.randi_range(0, 1) == 0 else -1.0
    position_in_world = Vector2(-100 if direction > 0 else game.WIDTH + 100, hover.y - 80)
    state = "approach"
    age = 0.0
    raid_started.emit(int(target["source"]))
    queue_redraw()

func _depart() -> void:
    if not target.is_empty():
        target.erase("abducting")
    state = "depart"
    age = 0.0

func _draw() -> void:
    if state == "idle":
        return
    var saucer: Vector2 = position_in_world
    if state in ["hover", "lift"]:
        saucer += Vector2(0, sin(clock * 3.0) * 3)
    if state == "lift":
        var top: Vector2 = saucer + Vector2(0, 12)
        var bottom: Vector2 = foot + Vector2(0, 2)
        var cone := PackedVector2Array([top + Vector2(-13, 0), top + Vector2(13, 0), bottom + Vector2(34, 0), bottom - Vector2(34, 0)])
        draw_colored_polygon(cone, Color(0.38, 1.0, 0.72, 0.20 + sin(clock * 22) * 0.04))
        draw_line(top + Vector2(-13, 0), bottom - Vector2(34, 0), Color(0.55, 1, 0.8, 0.6), 2, true)
        draw_line(top + Vector2(13, 0), bottom + Vector2(34, 0), Color(0.55, 1, 0.8, 0.6), 2, true)
        for ring in range(5):
            var fraction: float = fposmod(float(ring) / 5 + clock * 0.7, 1.0)
            var center: Vector2 = bottom.lerp(top, fraction)
            draw_set_transform(center, 0, Vector2(1, 0.23))
            draw_arc(Vector2.ZERO, lerpf(32, 13, fraction), 0, TAU, 32, Color(0.6, 1, 0.85, 0.45), 2, true)
        var progress: float = clampf(age / 3.2, 0, 1)
        var rider: Vector2 = foot.lerp(saucer + Vector2(0, 22), smoothstep(0, 1, progress))
        rider.x += sin(clock * 21) * 5 * sin(progress * PI)
        draw_set_transform(rider, sin(clock * 18) * 0.20, Vector2.ONE * lerpf(1, 0.55, progress))
        var variant: int = game._passenger_variant(target)
        if int(clock * 10) % 2 == 0:
            SPRITES.rider(self, Vector2.ZERO, variant, 2)
        else:
            SPRITES.rider(self, Vector2.ZERO, variant, 1)
        draw_set_transform(Vector2.ZERO)
    # Draw the saucer last so the passenger disappears into its underside.
    SPRITES.ship(self, 2, Rect2(saucer - Vector2(52, 26), Vector2(104, 52)))
    if state in ["approach", "hover"]:
        draw_string(ThemeDB.fallback_font, saucer + Vector2(-45, -38), "ABDUCTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a0ffd8"))
