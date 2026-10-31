extends Node2D
## Rendered particles and pieces of the actual taxi sprite; no physics bodies linger.
const SPRITES = preload("res://scripts/sprites.gd")
const DURATION: float = 1.4
var age: float = 0.0
var sparks: Array[Dictionary] = []
var clouds: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var drift := Vector2.ZERO

func ignite(center: Vector2, impact_velocity: Vector2) -> void:
    position = center
    age = 0.0
    visible = true
    z_index = 20
    drift = impact_velocity.limit_length(280) * 0.2
    sparks.clear()
    clouds.clear()
    debris.clear()
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for i in range(64):
        var direction := Vector2.from_angle(rng.randf_range(0, TAU))
        sparks.append({"velocity": direction * rng.randf_range(130, 450) + drift, "life": rng.randf_range(0.45, 1.3), "width": rng.randf_range(1.0, 2.7)})
    for i in range(18):
        clouds.append({"velocity": Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(35, 140) + drift, "radius": rng.randf_range(13, 29), "phase": rng.randf_range(0, TAU)})
    for i in range(8):
        debris.append({"velocity": Vector2.from_angle(float(i) / 8 * TAU + rng.randf_range(-0.2, 0.2)) * rng.randf_range(110, 240) + drift, "spin": rng.randf_range(-9, 9), "frame": i})
    queue_redraw()

func advance(dt: float) -> bool:
    age += maxf(0.0, dt)
    queue_redraw()
    return age >= DURATION

func shake_offset() -> Vector2:
    var strength: float = 9.0 * pow(maxf(0, 1.0 - age / 0.65), 2)
    return Vector2(sin(age * 91), cos(age * 117)) * strength

func travel(velocity: Vector2, t: float, gravity: float = 0.0) -> Vector2:
    return velocity * (1.0 - exp(-t * 1.8)) / 1.8 + Vector2(0, gravity * t * t)

func _draw() -> void:
    if age >= DURATION:
        return
    var fade: float = clampf(1.0 - age / DURATION, 0, 1)
    # Smoke stays behind the bright fire, sparks and flying taxi panels.
    for cloud in clouds:
        var center: Vector2 = travel(cloud["velocity"], age) + Vector2(0, -age * 26)
        var radius: float = float(cloud["radius"]) * (0.45 + age * 1.8)
        draw_circle(center, radius, Color(0.12, 0.15, 0.2, fade * 0.45))
    var ring_fade: float = maxf(0, 1.0 - age / 0.75)
    draw_arc(Vector2.ZERO, 20 + age * 310, 0, TAU, 96, Color(0.55, 0.91, 1.0, ring_fade * 0.85), maxf(1, ring_fade * 6), true)
    draw_arc(Vector2.ZERO, 15 + age * 245, 0, TAU, 80, Color(1.0, 0.52, 0.15, ring_fade * 0.55), 2, true)
    for cloud in clouds:
        var burn: float = maxf(0, 1.0 - age / 0.78)
        var center: Vector2 = travel(cloud["velocity"], age * 0.8)
        var radius: float = float(cloud["radius"]) * (0.35 + age * 1.9)
        var hot: Color = Color("fff1a8").lerp(Color("ff521a"), clampf(age * 2, 0, 1))
        hot.a = burn * 0.8
        draw_circle(center, radius * 1.55, Color(1, 0.25, 0.03, burn * 0.055))
        draw_circle(center, radius, hot)
        draw_circle(center + Vector2(-radius * 0.18, -radius * 0.15), radius * 0.48, Color(1, 0.86, 0.4, burn * burn))
    SPRITES._ensure()
    var texture: Texture2D = SPRITES.frames[0]
    for piece in debris:
        var index: int = int(piece["frame"])
        var cell := texture.get_size() / Vector2(4, 2)
        var region := Rect2(Vector2(index % 4, index / 4) * cell, cell)
        draw_set_transform(travel(piece["velocity"], age, 90), age * float(piece["spin"]))
        draw_texture_rect_region(texture, Rect2(-Vector2(18.5, 19.5) * 0.5, Vector2(18.5, 19.5)), region, Color(1, 0.86, 0.7, fade))
    draw_set_transform(Vector2.ZERO)
    for spark in sparks:
        var life: float = maxf(0, 1.0 - age / float(spark["life"]))
        if life <= 0:
            continue
        var tip: Vector2 = travel(spark["velocity"], age, 65)
        var tail: Vector2 = travel(spark["velocity"], maxf(0, age - 0.045), 65)
        draw_line(tail, tip, Color(1, 0.7 + life * 0.3, 0.22 + life * 0.6, life), float(spark["width"]), true)
    var flash: float = maxf(0, 1.0 - age / 0.13)
    draw_circle(Vector2.ZERO, 38 + age * 100, Color(1, 0.97, 0.84, flash))
    draw_circle(Vector2.ZERO, 70 + age * 160, Color(1, 0.7, 0.25, flash * 0.12))
