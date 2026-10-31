extends CharacterBody2D
const SPRITES = preload("res://scripts/sprites.gd")

signal landed(pad_id: int)
signal damaged(amount: float)
signal black_hole_entered(center: Vector2)
signal black_hole_lost

@export var gravity: float = 300.0
@export var lift: float = 520.0
@export var steering: float = 950.0
@export var top_speed: float = 330.0
var fuel: float = 140.0
var hull: float = 100.0
var fuel_capacity: float = 140.0
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
var visual_time: float = 0.0
var visual_tilt: float = 0.0
var facing: float = 1.0
var exhaust: Array = []
var damage_smoke: Array[Dictionary] = []
var smoke_clock: float = 0.0
const MAX_DAMAGE_SMOKE: int = 64
var environment: Node2D
var landing_horizontal: float = 155.0
var landing_vertical: float = 225.0
var capture_active: bool = false
var capture_time: float = 0.0
var capture_center := Vector2.ZERO
var capture_offset := Vector2.ZERO
var last_damage_reason: String = "HARD IMPACT"

func _physics_process(dt: float) -> void:
    dt = clampf(dt, 0.0, 0.05)
    visual_time += dt
    _update_damage_smoke(dt)
    visual_tilt = lerpf(visual_tilt, velocity.x / top_speed * 0.08, minf(dt * 7.0, 1.0))
    for particle in exhaust:
        particle["position"] += particle["velocity"] * dt
        particle["life"] -= dt
    for index in range(exhaust.size() - 1, -1, -1):
        if float(exhaust[index]["life"]) <= 0.0:
            exhaust.remove_at(index)
    if engine_on and not input_locked:
        exhaust.append({"position": global_position + Vector2(randf_range(-12, 12), 22), "velocity": Vector2(randf_range(-15, 15), randf_range(45, 110)), "life": 0.45})
    invulnerable_timer = maxf(0.0, invulnerable_timer - dt)
    bounce_timer = maxf(0.0, bounce_timer - dt)
    if capture_active:
        _animate_capture(dt)
        return
    if input_locked:
        engine_on = false
        queue_redraw()
        return
    var axis: float = Input.get_axis("move_left", "move_right")
    if absf(axis) > 0.05:
        facing = signf(axis)
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
        engine_on = false
        thrust_level = 0.0
        velocity = Vector2.ZERO
        if up and fuel > 0.0:
            landed_on = -1
            global_position.y -= 7.0
            velocity.y = -75.0
        else:
            queue_redraw()
            return
    var old_pos: Vector2 = global_position
    var control: float = 1.0 + engine_level * 0.16
    var response: float = steering * control * (1.0 + stabilizer_level * 0.08)
    if absf(axis) >= 0.05 and fuel > 0.0:
        velocity.x = move_toward(velocity.x, axis * top_speed * control, response * dt)
        fuel = maxf(0.0, fuel - absf(axis) * 0.5 * dt)
    else:
        # Coasting retains inertia and allows gravity gradients to bend the path.
        velocity.x *= exp(-0.65 * dt)
    engine_on = up and fuel > 0.0
    thrust_level = 1.0 if engine_on else 0.0
    velocity.y += gravity * dt
    if is_instance_valid(environment):
        velocity += environment.field_at(global_position) * dt
    if engine_on:
        velocity.y -= lift * control * dt
        fuel = maxf(0.0, fuel - 2.7 * dt)
    if brake and fuel > 0.0:
        var brake_strength: float = 680.0 * (1.0 + stabilizer_level * 0.28)
        velocity.x = move_toward(velocity.x, 0.0, brake_strength * dt)
        velocity.y = move_toward(velocity.y, 38.0, brake_strength * dt)
        if fuel > 0.0:
            fuel = maxf(0.0, fuel - 0.9 * dt)
    velocity.x = clampf(velocity.x, -top_speed * control * 1.2, top_speed * control * 1.2)
    velocity.y = clampf(velocity.y, -280.0 * control, 340.0)
    global_position += velocity * dt
    global_position.x = clampf(global_position.x, 35.0, world_width - 35.0)
    global_position.y = maxf(global_position.y, 128.0)
    if global_position.y <= 128.0 and velocity.y < 0.0:
        velocity.y = 0.0
    if global_position.x <= 35.0 or global_position.x >= world_width - 35.0:
        velocity.x = 0.0
    if is_instance_valid(environment):
        var collision: Dictionary = environment.resolve_motion(old_pos, global_position, velocity)
        if collision.get("captured", false):
            _begin_capture(collision["center"])
            return
        global_position = collision["position"]
        velocity = collision["velocity"]
        if collision.get("collided", false):
            var damage: float = impact_damage(float(collision["speed"]))
            if damage > 0:
                _take_damage(damage, str(collision["name"]))
    # Pads are one-way surfaces. Detect crossing from above; a generous landing
    # corridor and auto-stabilization replace the previous collision lottery.
    if velocity.y >= -5.0 and bounce_timer <= 0.0:
        for pad in pads:
            var pad_x: float = float(pad["x"])
            var pad_y: float = float(pad["y"])
            var pad_width: float = float(pad["width"])
            var surface: float = pad_y - 21.0
            var crossing: bool = old_pos.y <= surface + 0.01 and global_position.y >= surface
            var fraction: float = clampf((surface - old_pos.y) / maxf(global_position.y - old_pos.y, 0.001), 0.0, 1.0)
            var touchdown_x: float = lerpf(old_pos.x, global_position.x, fraction)
            if crossing and absf(touchdown_x - pad_x) <= pad_width * 0.5 - 35.0:
                global_position.x = touchdown_x
                global_position.y = surface
                if absf(velocity.x) <= landing_horizontal + stabilizer_level * 20.0 and velocity.y <= landing_vertical + stabilizer_level * 18.0:
                    velocity = Vector2.ZERO
                    engine_on = false
                    landed_on = int(pad["id"])
                    landed.emit(landed_on)
                else:
                    var impact: float = maxf(velocity.y, absf(velocity.x) * 0.75)
                    velocity.y = -maxf(45.0, velocity.y * 0.48)
                    velocity.x *= 0.42
                    bounce_timer = 0.35
                    _take_damage(maxf(1.0, impact_damage(impact)), "HARD LANDING")
                queue_redraw()
                return
    # Platforms are solid from the sides and underneath; top landings above
    # have already settled or bounced. This also catches partial edge strikes.
    if is_instance_valid(environment):
        for pad in pads:
            var center := Vector2(float(pad["x"]), float(pad["y"]) + 12.5)
            var hit: Dictionary = environment._box_hit(old_pos, global_position, center, Vector2(float(pad["width"]) * 0.5 + 35, 33.5))
            if not hit.is_empty():
                var normal: Vector2 = hit["normal"]
                var normal_speed: float = maxf(0.0, -velocity.dot(normal))
                global_position = hit["position"]
                if velocity.dot(normal) < 0:
                    velocity -= normal * velocity.dot(normal) * 1.48
                _take_damage(impact_damage(normal_speed), "PLATFORM STRIKE")
                break
    # Moving hazards can push during depenetration; keep the final result in bounds.
    global_position.x = clampf(global_position.x, 35.0, world_width - 35.0)
    global_position.y = maxf(global_position.y, 128.0)
    if global_position.y > floor_height - 21.0:
        global_position.y = floor_height - 21.0
        var ground_speed: float = maxf(0.0, velocity.y)
        velocity = Vector2(velocity.x * 0.65, -maxf(35.0, ground_speed * 0.48))
        if bounce_timer <= 0.0:
            _take_damage(impact_damage(ground_speed), "GROUND STRIKE")
            bounce_timer = 0.65
    queue_redraw()

func impact_damage(speed: float) -> float:
    return ceilf(clampf((speed - 45.0) * 0.09, 0.0, 45.0))

func _begin_capture(center: Vector2) -> void:
    if capture_active or input_locked:
        return
    damage_smoke.clear()
    smoke_clock = 0.0
    capture_active = true
    capture_time = 0.0
    capture_center = center
    capture_offset = global_position - center
    if capture_offset.length() < 20.0:
        capture_offset = Vector2(45, 0)
    engine_on = false
    thrust_level = 0.0
    velocity = Vector2.ZERO
    landed_on = -1
    black_hole_entered.emit(center)

func _animate_capture(dt: float) -> void:
    capture_time += dt
    var progress: float = clampf(capture_time / 1.35, 0.0, 1.0)
    global_position = capture_center + capture_offset.rotated(progress * TAU * 2.5) * pow(1.0 - progress, 1.5)
    rotation = progress * TAU * 4.0
    scale = Vector2(maxf(0.01, 1.0 - progress), maxf(0.01, (1.0 - progress) * (1.0 + sin(progress * PI) * 2.0)))
    modulate.a = 1.0 - progress * 0.5
    queue_redraw()
    if progress >= 1.0:
        capture_active = false
        input_locked = true
        black_hole_lost.emit()

func _take_damage(amount: float, reason: String = "HARD IMPACT") -> void:
    if invulnerable_timer > 0.0 or amount <= 0.0:
        return
    last_damage_reason = reason
    hull = maxf(0.0, hull - amount)
    invulnerable_timer = 0.8
    damaged.emit(amount)

func refuel(amount: float) -> void:
    fuel = minf(fuel_capacity, fuel + amount)

func repair(amount: float) -> void:
    hull = minf(100.0, hull + amount)
    if hull > 55.0:
        damage_smoke.clear()
        smoke_clock = 0.0
    queue_redraw()

func damage_stage() -> int:
    if hull > 75:
        return 0
    if hull > 55:
        return 1
    if hull > 30:
        return 2
    if hull > 15:
        return 3
    return 4

func smoke_rate() -> float:
    if hull <= 0 or capture_active or input_locked or not visible:
        return 0.0
    match damage_stage():
        2: return 8.0
        3: return 18.0
        4: return 30.0
    return 0.0

func _update_damage_smoke(dt: float) -> void:
    for particle in damage_smoke:
        particle["position"] += Vector2(particle["velocity"]) * dt
        particle["life"] -= dt
    for index in range(damage_smoke.size() - 1, -1, -1):
        if float(damage_smoke[index]["life"]) <= 0:
            damage_smoke.remove_at(index)
    var rate: float = smoke_rate()
    if rate <= 0:
        smoke_clock = 0.0
        return
    smoke_clock += dt
    while smoke_clock >= 1.0 / rate:
        smoke_clock -= 1.0 / rate
        if damage_smoke.size() >= MAX_DAMAGE_SMOKE:
            break
        var severity: float = clampf((55.0 - hull) / 55.0, 0, 1)
        var lifetime: float = lerpf(0.85, 1.45, severity)
        damage_smoke.append({
            "position": global_position + Vector2(-25 * facing, -4).rotated(visual_tilt),
            "velocity": velocity * 0.12 + Vector2(randf_range(-12, 12), -randf_range(30, 55)),
            "life": lifetime, "lifetime": lifetime,
            "radius": lerpf(3.0, 6.5, severity), "severity": severity
        })

func _draw_hull_damage() -> void:
    var stage: int = damage_stage()
    if stage == 0:
        return
    # Marks stay in sprite coordinates so they turn and bank with the body.
    draw_ellipse_scorch(Vector2(-23, 3), Vector2(8, 5), Color(0.14, 0.1, 0.08, 0.28 + stage * 0.09))
    draw_polyline(PackedVector2Array([Vector2(-30, 5), Vector2(-24, 8), Vector2(-18, 5)]), Color("5c4840"), 1.5, true)
    draw_line(Vector2(-29, 10), Vector2(-20, 11), Color("a2acaf"), 1, true)
    if stage >= 2:
        draw_ellipse_scorch(Vector2(17, 10), Vector2(10, 4), Color(0.1, 0.12, 0.14, 0.48))
        draw_polyline(PackedVector2Array([Vector2(8, 9), Vector2(12, 12), Vector2(18, 8), Vector2(25, 11)]), Color("4b3430"), 2, true)
        draw_line(Vector2(-32, -3), Vector2(-21, 0), Color("211c1a"), 2, true)
    if stage >= 3:
        draw_polyline(PackedVector2Array([Vector2(12, -9), Vector2(7, -4), Vector2(14, -1), Vector2(9, 4)]), Color("b6e6e5"), 1, true)
        draw_line(Vector2(7, -4), Vector2(2, -6), Color("b6e6e5"), 1, true)
        draw_line(Vector2(-31, 15), Vector2(-13, 17), Color("3e3837"), 3, true)
        draw_circle(Vector2(-25, 1), 3.0, Color(1, 0.25, 0.04, 0.25 + sin(visual_time * 19) * 0.12))
    if stage >= 4:
        var flicker: float = 0.6 + sin(visual_time * 28) * 0.35
        draw_circle(Vector2(-25, -2), 5, Color(1, 0.3, 0.03, flicker * 0.3))
        draw_circle(Vector2(-25, -2), 2, Color(1, 0.75, 0.2, flicker))
        for index in range(3):
            var t: float = fposmod(visual_time * 2.5 + index * 0.33, 1.0)
            var start := Vector2(-25 - t * 10, -2 - t * 14)
            draw_line(start, start + Vector2(-2, -3), Color(1, 0.7, 0.1, 1.0 - t), 1, true)

func draw_ellipse_scorch(center: Vector2, radius: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for index in range(20):
        var angle: float = float(index) / 20.0 * TAU
        points.append(center + Vector2(cos(angle), sin(angle)) * radius)
    draw_colored_polygon(points, color)

func _draw() -> void:
    for particle in damage_smoke:
        var progress: float = 1.0 - float(particle["life"]) / float(particle["lifetime"])
        var opacity: float = minf(progress * 10, 1) * pow(1.0 - progress, 1.4)
        var severity: float = float(particle["severity"])
        var shade: float = lerpf(0.62, 0.19, severity)
        var radius: float = float(particle["radius"]) * (0.6 + progress * 2.7)
        var center: Vector2 = to_local(particle["position"])
        draw_circle(center, radius, Color(shade, shade + 0.025, shade + 0.04, opacity * 0.65))
        draw_circle(center + Vector2(-radius * 0.25, -radius * 0.2), radius * 0.65, Color(shade + 0.1, shade + 0.12, shade + 0.14, opacity * 0.2))
    for particle in exhaust:
        var life: float = float(particle["life"]) / 0.45
        draw_circle(particle["position"] - global_position, 2.5 * life, Color(0.38, 0.85, 1.0, life * 0.4))
    draw_set_transform(Vector2.ZERO, visual_tilt, Vector2(facing, 1))
    if engine_on:
        var flame: float = 32.0 + sin(visual_time * 63) * 6.0
        for x in [-14, 14]:
            draw_circle(Vector2(x, 19), 17, Color(0.2, 0.7, 1.0, 0.06))
            draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 13), Vector2(x + 6, 13), Vector2(x, flame)]), Color("4fbae5"))
            draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 13), Vector2(x + 3, 13), Vector2(x, flame - 7)]), Color("d5fbff"))
    var sprite: int = 1 if Input.is_action_pressed("brake") and fuel > 0 and not input_locked else 0
    SPRITES.ship(self, sprite, Rect2(-37, -18, 74, 39))
    _draw_hull_damage()
    if invulnerable_timer > 0.0:
        draw_arc(Vector2.ZERO, 41, 0, TAU, 40, Color(1.0, 0.35, 0.18, invulnerable_timer * 0.7), 2.0, true)
