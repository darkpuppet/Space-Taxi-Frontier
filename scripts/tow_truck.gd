extends Node2D
## Recovery tractor rig bypasses hazards while the disabled taxi is secured.
signal driver_spoke(line: String)
signal delivered

const HITCH := Vector2(0, 85)
const TAXI_ROOF: float = 20.0
const PICKUP_CLEARANCE: float = 120.0
const LIFT_HEIGHT: float = 75.0
const SPEED: float = 420.0
const TRUCK_TEXTURE: Texture2D = preload("res://assets/sprites/frontier-tow-truck-v2.png")
const SPRITE_FPS: float = 12.0
const CHATTER: Dictionary = {
    "approach": [
        "Well butter my biscuit, you ran 'er dry!",
        "Hold tight, partner. This heap still pulls!",
        "Ain't no gas station out in that nebula!"
    ],
    "hook": [
        "Gotcha! That chain's stronger than it looks.",
        "Easy now. She's held together with stubborn.",
        "Don't mind the rust. That's structural."
    ],
    "lift": [
        "Up she comes! Like pullin' a stump on Sunday.",
        "This winch hauled Grandpa's barn. You'll be fine.",
        "C'mon, old girl. Show 'em what scrap can do!"
    ],
    "return": [
        "Yeehaw! Next stop, the fuel pump!",
        "Haulin' taxis beats haulin' moon hogs!",
        "My other spaceship's a tractor."
    ],
    "lower": [
        "Whoa there. Settin' her down gentle as an egg.",
        "Fuel pad dead ahead. Even my brakes found it!",
        "Easy does it. That pump ain't goin' nowhere."
    ],
    "depart": [
        "There ya go. Feed 'er before you floor 'er!",
        "Back at the pump, slicker'n a greased comet!",
        "Y'all come back. Preferably with fuel!"
    ]
}
var state: String = "idle"
var age: float = 0.0
var clock: float = 0.0
var taxi: CharacterBody2D
var destination := Vector2.ZERO
var pickup := Vector2.ZERO
var hook_length: float = 20.0
var driver_line: String = ""
var facing: float = 1.0
var rng := RandomNumberGenerator.new()
var sprite: Sprite2D
var lift_origin := Vector2.ZERO
var lower_origin := Vector2.ZERO
var last_lines: Dictionary = {}

func _ready() -> void:
    z_index = 8
    rng.randomize()
    sprite = Sprite2D.new()
    sprite.texture = TRUCK_TEXTURE
    sprite.hframes = 4
    sprite.vframes = 2
    # Keep the original generated PNG intact; scale each cell to 160 world units.
    sprite.scale = Vector2.ONE * (160.0 * sprite.hframes / TRUCK_TEXTURE.get_width())
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.offset = Vector2(0, -5) / sprite.scale
    sprite.visible = false
    add_child(sprite)

func start(ship: CharacterBody2D, dock: Vector2) -> void:
    if state != "idle" or not is_instance_valid(ship):
        return
    taxi = ship
    destination = dock
    pickup = taxi.position
    taxi.input_locked = true
    taxi.engine_on = false
    taxi.thrust_level = 0.0
    taxi.velocity = Vector2.ZERO
    taxi.landed_on = -1
    taxi.fuel_service_active = false
    clock = 0.0
    position = pickup + Vector2(480 if pickup.x < 1200 else -480, -150)
    hook_length = 20.0
    _enter("approach")

func reset() -> void:
    if is_instance_valid(taxi) and state not in ["idle", "depart"]:
        taxi.input_locked = false
    state = "idle"
    driver_line = ""
    taxi = null
    if is_instance_valid(sprite):
        sprite.visible = false
    queue_redraw()

func _enter(next_state: String) -> void:
    state = next_state
    age = 0.0
    _update_sprite()
    if CHATTER.has(state):
        var lines: Array = CHATTER[state]
        var index: int = rng.randi_range(0, lines.size() - 1)
        if index == int(last_lines.get(state, -1)):
            index = (index + 1) % lines.size()
        last_lines[state] = index
        driver_line = str(lines[index])
        driver_spoke.emit(driver_line)
    queue_redraw()

func _update_sprite() -> void:
    sprite.visible = state != "idle"
    var flying: bool = state in ["approach", "lift", "return", "depart"]
    sprite.frame_coords = Vector2i(int(clock * SPRITE_FPS) % sprite.hframes, 1 if flying else 0)
    sprite.flip_h = facing < 0
    sprite.position.y = sin(clock * 41) * 0.7 + sin(clock * 4) * (1.2 if flying else 0.5)
    sprite.rotation = sin(clock * 29) * 0.009

func advance(dt: float) -> void:
    if get_tree().paused or state == "idle" or dt <= 0:
        return
    if not is_instance_valid(taxi):
        reset()
        return
    age += dt
    clock += dt
    match state:
        "approach":
            _move_to(pickup - Vector2(0, PICKUP_CLEARANCE), dt)
            if position.distance_to(pickup - Vector2(0, PICKUP_CLEARANCE)) < 0.1:
                _enter("hook")
        "hook":
            hook_length = lerpf(20, PICKUP_CLEARANCE - TAXI_ROOF, minf(age / 1.4, 1))
            if age >= 1.4:
                lift_origin = position
                _enter("lift")
        "lift":
            var progress: float = smoothstep(0.0, 1.0, minf(age / 1.8, 1.0))
            position = lift_origin - Vector2(0, LIFT_HEIGHT * progress)
            hook_length = lerpf(PICKUP_CLEARANCE - TAXI_ROOF, HITCH.y - TAXI_ROOF, progress)
            taxi.position = position + Vector2(0, hook_length + TAXI_ROOF)
            if age >= 1.8:
                _enter("return")
        "return":
            _move_to(destination - HITCH - Vector2(0, LIFT_HEIGHT), dt)
            taxi.position = position + HITCH
            if age >= 1.6 and position.distance_to(destination - HITCH - Vector2(0, LIFT_HEIGHT)) < 0.1:
                lower_origin = position
                _enter("lower")
        "lower":
            var progress: float = smoothstep(0.0, 1.0, minf(age / 2.0, 1.0))
            # Hover above the dock while the winch pays out the cable.
            taxi.position = (lower_origin + HITCH).lerp(destination, progress)
            hook_length = taxi.position.y - position.y - TAXI_ROOF
            if age >= 2.0:
                taxi.position = destination
                taxi.velocity = Vector2.ZERO
                taxi.landed_on = 2
                taxi.refuel(45.0)
                taxi.input_locked = false
                taxi.invulnerable_timer = maxf(taxi.invulnerable_timer, 1.5)
                _enter("depart")
                delivered.emit()
        "depart":
            hook_length = move_toward(hook_length, 20.0, dt * 150.0)
            position += Vector2(260 * facing, -140) * dt
            if age >= 2.0:
                reset()
    _update_sprite()
    queue_redraw()

func _move_to(target: Vector2, dt: float) -> void:
    if absf(target.x - position.x) > 1:
        facing = signf(target.x - position.x)
    position = position.move_toward(target, SPEED * dt)

func _draw() -> void:
    if state == "idle":
        return
    # Cable originates at the rusty crane, and ends at the taxi's roof.
    var boom := Vector2(-28 * facing, -50)
    var hook := Vector2(0, hook_length)
    draw_line(boom, hook, Color("302a24"), 5)
    draw_line(boom, hook, Color("b6a17b"), 2)
    var cable_length: float = boom.distance_to(hook)
    for link in range(1, int(cable_length / 9)):
        var point: Vector2 = boom.lerp(hook, float(link) * 9.0 / cable_length)
        draw_line(point - Vector2(2, 0), point + Vector2(2, 0), Color("6d6654"), 2)
    draw_arc(Vector2(4, hook_length), 5, 0, PI * 1.5, 10, Color("c2b9a2"), 3)
    if state in ["lift", "return", "lower"]:
        draw_arc(taxi.position - position, 46, 0, TAU, 40, Color("7edbd033"), 3)
    draw_string(ThemeDB.fallback_font, Vector2(-47, 55), "BUBBA'S TOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dcc49a"))
    var text_width: float = ThemeDB.fallback_font.get_string_size(driver_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
    var bubble_position := Vector2(-text_width * 0.5 - 10, -100)
    # Keep Bubba's words inside the camera and below the cockpit header.
    var screen_to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
    var viewport_size: Vector2 = get_viewport_rect().size
    var safe_min: Vector2 = screen_to_local * Vector2(16, 165)
    var safe_max: Vector2 = screen_to_local * (viewport_size - Vector2(16, 90))
    bubble_position.x = clampf(bubble_position.x, safe_min.x, maxf(safe_min.x, safe_max.x - text_width - 20))
    bubble_position.y = clampf(bubble_position.y, safe_min.y, maxf(safe_min.y, safe_max.y - 29))
    draw_style_box(_bubble(), Rect2(bubble_position, Vector2(text_width + 20, 29)))
    var tail: Vector2 = bubble_position + Vector2(text_width * 0.5 + 10, 29)
    draw_colored_polygon(PackedVector2Array([tail - Vector2(5, 0), tail + Vector2(5, 0), tail + Vector2(0, 7)]), Color("e6d5aa"))
    draw_string(ThemeDB.fallback_font, bubble_position + Vector2(10, 20), driver_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("302b25"))

func _bubble() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("e6d5aa")
    style.set_corner_radius_all(5)
    return style
