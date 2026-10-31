extends CharacterBody2D

signal landed(pad_id: int)
signal damaged(amount: float)

@export var gravity: float = 300.0
@export var lift: float = 520.0
@export var steering: float = 950.0
@export var top_speed: float = 330.0
var fuel: float = 100.0
var hull: float = 100.0
var fuel_capacity: float = 100.0
var engine_level: int = 0
var stabilizer_level: int = 0
var landed_on: int = -1
var engine_on: bool = false
var thrust_level: float = 0.0
var pads: Array = []
var world_width: float = 2200.0
var floor_height: float = 660.0
var invulnerable_timer: float = 0.0
var bounce_timer: float = 0.0
var input_locked: bool = false

func _physics_process(dt: float) -> void:
    invulnerable_timer = maxf(0.0, invulnerable_timer - dt)
    bounce_timer = maxf(0.0, bounce_timer - dt)
    if input_locked:
        engine_on = false
        queue_redraw()
        return
    var axis: float = Input.get_axis("move_left", "move_right")
    var up: bool = Input.is_action_pressed("thrust")
    var brake: bool = Input.is_action_pressed("brake")
    # Physical-key fallbacks ensure controls work with imported projects/keyboards.
    if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
        axis = -1.0
    if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
        axis = 1.0
    up = up or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)
    brake = brake or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
    if landed_on != -1:
        velocity = Vector2.ZERO
        if up and fuel > 0.0:
            landed_on = -1
            global_position.y -= 7.0
            velocity.y = -75.0
        else:
            queue_redraw()
            return
    var old_pos: Vector2 = global_position
    var old_velocity: Vector2 = velocity
    var control: float = 1.0 + engine_level * 0.16
    var response: float = steering * control * (1.0 + stabilizer_level * 0.08)
    velocity.x = move_toward(velocity.x, axis * top_speed * control, response * dt)
    if absf(axis) < 0.05:
        velocity.x = move_toward(velocity.x, 0.0, 165.0 * dt)
    engine_on = up and fuel > 0.0
    thrust_level = 1.0 if engine_on else 0.0
    velocity.y += gravity * dt
    if engine_on:
        velocity.y -= lift * control * dt
        fuel = maxf(0.0, fuel - 4.2 * dt)
    if brake:
        var brake_strength: float = 680.0 * (1.0 + stabilizer_level * 0.28)
        velocity.x = move_toward(velocity.x, 0.0, brake_strength * dt)
        velocity.y = move_toward(velocity.y, 0.0, brake_strength * dt)
        if fuel > 0.0:
            fuel = maxf(0.0, fuel - 1.3 * dt)
    velocity.y = clampf(velocity.y, -280.0 * control, 340.0)
    global_position += velocity * dt
    global_position.x = clampf(global_position.x, 35.0, world_width - 35.0)
    global_position.y = maxf(global_position.y, 55.0)
    if global_position.y <= 55.0 and velocity.y < 0.0:
        velocity.y = 0.0
    if global_position.x <= 35.0 or global_position.x >= world_width - 35.0:
        velocity.x = 0.0
    # Pads are one-way surfaces. Detect crossing from above; a generous landing
    # corridor and auto-stabilization replace the previous collision lottery.
    if velocity.y >= -5.0 and bounce_timer <= 0.0:
        for pad in pads:
            var pad_x: float = float(pad["x"])
            var pad_y: float = float(pad["y"])
            var pad_width: float = float(pad["width"])
            var surface: float = pad_y - 21.0
            if absf(global_position.x - pad_x) < pad_width * 0.5 - 17.0 and old_pos.y <= surface + 9.0 and global_position.y >= surface:
                global_position.y = surface
                if absf(velocity.x) < 165.0 + stabilizer_level * 30.0 and velocity.y < 245.0 + stabilizer_level * 25.0:
                    velocity = Vector2.ZERO
                    landed_on = int(pad["id"])
                    landed.emit(landed_on)
                else:
                    velocity.y = -90.0
                    velocity.x *= 0.42
                    bounce_timer = 0.35
                    _take_damage(16.0)
                queue_redraw()
                return
    if global_position.y > floor_height - 21.0:
        global_position.y = floor_height - 21.0
        velocity = Vector2(velocity.x * 0.25, -95.0)
        if bounce_timer <= 0.0:
            _take_damage(20.0)
            bounce_timer = 0.65
    queue_redraw()

func _take_damage(amount: float) -> void:
    if invulnerable_timer > 0.0:
        return
    hull = maxf(0.0, hull - amount)
    invulnerable_timer = 0.8
    damaged.emit(amount)

func refuel(amount: float) -> void:
    fuel = minf(fuel_capacity, fuel + amount)

func repair(amount: float) -> void:
    hull = minf(100.0, hull + amount)

func _draw() -> void:
    if engine_on:
        draw_colored_polygon(PackedVector2Array([Vector2(-12, 12), Vector2(12, 12), Vector2(0, 38 + randf_range(0, 11))]), Color(0.97, 0.39, 0.09, 0.72))
        draw_colored_polygon(PackedVector2Array([Vector2(-6, 12), Vector2(6, 12), Vector2(0, 29 + randf_range(0, 7))]), Color(0.65, 0.92, 1.0))
    draw_colored_polygon(PackedVector2Array([Vector2(-34, 3), Vector2(-24, -10), Vector2(12, -13), Vector2(30, -5), Vector2(34, 4), Vector2(25, 13), Vector2(-26, 13)]), Color(0.52, 0.62, 0.69))
    draw_colored_polygon(PackedVector2Array([Vector2(1, -11), Vector2(14, -11), Vector2(27, -4), Vector2(2, -3)]), Color(0.12, 0.62, 0.81))
    draw_line(Vector2(-29, 5), Vector2(29, 5), Color(0.13, 0.20, 0.27), 3.0)
    draw_line(Vector2(-21, 13), Vector2(-25, 20), Color(0.83, 0.85, 0.87), 3.0)
    draw_line(Vector2(19, 13), Vector2(23, 20), Color(0.83, 0.85, 0.87), 3.0)
    draw_circle(Vector2(-25, 20), 3.0, Color(1.0, 0.75, 0.25))
    draw_circle(Vector2(23, 20), 3.0, Color(1.0, 0.75, 0.25))
    if invulnerable_timer > 0.0:
        draw_arc(Vector2.ZERO, 41, 0, TAU, 40, Color(1.0, 0.35, 0.18, 0.6), 2.0)
