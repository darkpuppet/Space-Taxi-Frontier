extends Node2D
const SPRITES = preload("res://scripts/sprites.gd")
## Shared source of truth for rendered hazards and sampled gravity.
var config: Dictionary = {}
var planets: Array[Dictionary] = []
var aliens: Array[Dictionary] = []
var holes: Array[Dictionary] = []
var elapsed: float = 0.0
var taxi: CharacterBody2D
var asteroids: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var drones: Array[Dictionary] = []
var mines: Array[Dictionary] = []
var meteors: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var docking_pads: Array = []
var exit_open: bool = false
var exit_position := Vector2.ZERO

func configure(data: Dictionary) -> void:
    exit_open = false
    config = data
    docking_pads = preload("res://scripts/campaign.gd").pads_for(int(data["index"]))
    elapsed = 0.0
    planets.clear()
    aliens.clear()
    holes.clear()
    asteroids.clear()
    gates.clear()
    drones.clear()
    mines.clear()
    meteors.clear()
    beams.clear()
    for i in range(int(data["aliens"])):
        var home := Vector2(530 + i * 355, 350 + (i % 3) * 280)
        aliens.append({"home": home, "position": home, "phase": i * 1.7})
    for i in range(int(data["holes"])):
        var terminals: Array = preload("res://scripts/campaign.gd").pads_for(int(data["index"]))
        var left: float = float(terminals[i + 1]["x"])
        var right: float = float(terminals[i + 2]["x"])
        var home := Vector2((left + right) * 0.5, 650 + i * 200)
        # Keep drift out of vertical docking corridors; wells challenge transit.
        var drift: float = minf(105.0, (right - left) * 0.5 - 90.0)
        holes.append({"home": home, "position": home, "phase": i * 2.1, "radius": 18.0, "drift": maxf(20, drift)})
    for i in range(int(data["asteroids"])):
        asteroids.append({"position": Vector2(970 + i * 570, 540 + (i % 2) * 470), "kind": "asteroid"})
    for i in range(int(data["gates"])):
        gates.append({"position": Vector2(1040, 670), "kind": "gate"})
    for i in range(int(data["drones"])):
        var home := Vector2(1560 + i * 330, 510 + i * 450)
        drones.append({"position": home, "home": home, "kind": "drone"})
    for i in range(int(data["mines"])):
        mines.append({"position": Vector2(950 + i * 505, 1110 - i * 270), "kind": "mine"})
    for i in range(int(data["meteors"])):
        var home := Vector2(650 + i * 1000, 160 + i * 110)
        meteors.append({"position": home, "home": home, "kind": "meteor"})
    for i in range(int(data["beams"])):
        beams.append({"position": Vector2(1500, 850), "active": false, "kind": "beam"})
    queue_redraw()

func navigation_markers() -> Array:
    return aliens + holes + asteroids + gates + drones + mines + meteors + beams

func _physics_process(dt: float) -> void:
    elapsed += dt
    for alien in aliens:
        var phase: float = elapsed * (float(config["hazard_speed"]) + 0.16) + float(alien["phase"])
        alien["position"] = alien["home"] + Vector2(sin(phase) * 145, cos(phase * 1.3) * 55)
    for hole in holes:
        var phase: float = elapsed * float(config["hazard_speed"]) + float(hole["phase"])
        hole["position"] = hole["home"] + Vector2(sin(phase) * float(hole["drift"]), cos(phase * 0.8) * 25)
    for gate in gates:
        gate["position"].y = 670 + sin(elapsed * (0.45 + int(config["index"]) * 0.005)) * 80
    var docking_approach: bool = exit_open and is_instance_valid(taxi) and taxi.position.distance_to(exit_position) < 190
    if is_instance_valid(taxi):
        for pad in docking_pads:
            if taxi.position.distance_to(Vector2(float(pad["x"]), float(pad["y"]) - 21)) < 150:
                docking_approach = true
                break
    for drone in drones:
        var target: Vector2 = Vector2(drone["home"]) + Vector2(sin(elapsed * 0.6) * 80, cos(elapsed * 0.4) * 35)
        if exit_open and target.distance_to(exit_position) < 165:
            var away: Vector2 = Vector2(drone["home"]) - exit_position
            if away.length_squared() < 1:
                away = Vector2.RIGHT
            target = exit_position + away.normalized() * 220
        if not docking_approach and is_instance_valid(taxi) and taxi.landed_on == -1 and taxi.position.y > 210 and Vector2(drone["position"]).distance_to(taxi.position) < 240:
            target = taxi.position
        drone["position"] = Vector2(drone["position"]).move_toward(target, (42 + int(config["index"])) * dt)
        drone["position"].y = clampf(drone["position"].y, 210, 1210)
    for meteor in meteors:
        meteor["position"] = Vector2(fposmod(float(meteor["home"].x) + elapsed * 32, 2200) + 100, fposmod(float(meteor["home"].y) + elapsed * 65, 1220) + 100)
    for beam in beams:
        beam["active"] = fposmod(elapsed, 6.0) >= 3.0 and fposmod(elapsed, 6.0) < 4.8
    queue_redraw()

func _pull(position: Vector2, center: Vector2, strength: float, scale_radius: float) -> Vector2:
    var offset: Vector2 = center - position
    var distance: float = offset.length()
    if distance < 0.001:
        return Vector2.ZERO
    # Softened inverse-square falloff: finite even inside the event horizon.
    return offset / distance * strength / (1.0 + pow(distance / scale_radius, 2.0))

func field_at(position: Vector2) -> Vector2:
    var field := Vector2.ZERO
    for hole in holes:
        var distance: float = position.distance_to(hole["position"])
        field += _pull(position, hole["position"], 280.0 + float(config["index"]) * 2.0, 140.0) * (1.0 - smoothstep(90.0, 340.0, distance))
    # A stock engine can always overcome the bounded vertical component.
    return field.limit_length(210.0)

func _solids() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for family in [asteroids, aliens, drones, mines, meteors]:
        for body in family:
            var radius: float = 28 if family == asteroids else (24 if family == aliens else 18)
            result.append({"position": body["position"], "radius": radius, "name": str(body.get("kind", "alien")).to_upper() + " COLLISION"})
    for gate in gates:
        result.append({"position": gate["position"], "half_size": Vector2(9, 48), "name": "MOVING GATE"})
    for beam in beams:
        if bool(beam["active"]):
            result.append({"position": beam["position"], "half_size": Vector2(96, 6), "name": "ELECTRIC BEAM"})
    return result

func _circle_hit(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> Dictionary:
    var offset: Vector2 = start - center
    var motion: Vector2 = finish - start
    var normal: Vector2
    if offset.length_squared() <= radius * radius:
        # Keep tangential/outward input when a moving body overlaps the craft.
        # Projecting the old position alone traps the taxi against chasing drones.
        var escape: Vector2 = finish - center
        normal = escape.normalized() if escape.length_squared() > 0.0001 else Vector2.UP
        return {"time": 0.0, "normal": normal, "position": center + normal * maxf(radius + 0.5, escape.length())}
    var a: float = motion.length_squared()
    if a < 0.000001:
        return {}
    var b: float = offset.dot(motion)
    var c: float = offset.length_squared() - radius * radius
    var discriminant: float = b * b - a * c
    if discriminant < 0:
        return {}
    var time: float = (-b - sqrt(discriminant)) / a
    if time < 0 or time > 1:
        return {}
    var point: Vector2 = start + motion * time
    normal = (point - center).normalized()
    return {"time": time, "normal": normal, "position": point + normal * 0.5}

func _box_hit(start: Vector2, finish: Vector2, center: Vector2, half: Vector2) -> Dictionary:
    var low: Vector2 = center - half
    var high: Vector2 = center + half
    if Rect2(low, half * 2).has_point(start):
        var distances: Array = [start.x - low.x, high.x - start.x, start.y - low.y, high.y - start.y]
        var normals: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
        var nearest: int = 0
        for i in range(1, 4):
            if distances[i] < distances[nearest]:
                nearest = i
        return {"time": 0.0, "normal": normals[nearest], "position": start + normals[nearest] * (float(distances[nearest]) + 0.5)}
    var motion: Vector2 = finish - start
    var enter: float = 0.0
    var leave: float = 1.0
    var normal := Vector2.ZERO
    for axis in range(2):
        if absf(motion[axis]) < 0.000001:
            if start[axis] < low[axis] or start[axis] > high[axis]:
                return {}
            continue
        var first: float = (low[axis] - start[axis]) / motion[axis]
        var last: float = (high[axis] - start[axis]) / motion[axis]
        var face := Vector2.ZERO
        face[axis] = -1.0 if motion[axis] > 0 else 1.0
        if first > last:
            var swap: float = first
            first = last
            last = swap
        if first >= enter:
            enter = first
            normal = face
        leave = minf(leave, last)
        if enter > leave:
            return {}
    if enter < 0 or enter > 1 or normal == Vector2.ZERO:
        return {}
    return {"time": enter, "normal": normal, "position": start + motion * enter + normal * 0.5}

func resolve_motion(start: Vector2, finish: Vector2, velocity: Vector2, craft_radius: float = 35.0) -> Dictionary:
    var earliest: Dictionary = {}
    var earliest_time: float = 2.0
    for body in _solids():
        var hit: Dictionary
        if body.has("half_size"):
            hit = _box_hit(start, finish, body["position"], Vector2(body["half_size"]) + Vector2.ONE * craft_radius)
        else:
            hit = _circle_hit(start, finish, body["position"], float(body["radius"]) + craft_radius)
        if not hit.is_empty() and float(hit["time"]) < earliest_time:
            earliest = hit
            earliest_time = float(hit["time"])
            earliest["name"] = body["name"]
    for hole in holes:
        var hit: Dictionary = _circle_hit(start, finish, hole["position"], 36.0)
        if not hit.is_empty() and float(hit["time"]) <= earliest_time:
            return {"captured": true, "center": hole["position"]}
    if earliest.is_empty():
        return {"position": finish, "velocity": velocity, "collided": false}
    var normal: Vector2 = earliest["normal"]
    var impact_speed: float = maxf(0.0, -velocity.dot(normal))
    var bounce: Vector2 = velocity
    if velocity.dot(normal) < 0:
        bounce -= normal * velocity.dot(normal) * 1.48
    return {"position": earliest["position"], "velocity": bounce, "speed": impact_speed, "normal": normal, "name": earliest["name"], "collided": true}

func contact_at(position: Vector2) -> Dictionary:
    return resolve_motion(position, position, Vector2.ZERO)

func _draw() -> void:
    for hole in holes:
        var center: Vector2 = hole["position"]
        for ring in range(6, 0, -1):
            draw_arc(center, 18 + ring * 6, elapsed * (0.3 + ring * 0.08), elapsed * (0.3 + ring * 0.08) + 4.5, 60, Color(0.72, 0.4, 1.0, 0.55 - ring * 0.07), 2, true)
        for mote in range(12):
            var progress: float = fposmod(elapsed * 0.34 + mote / 12.0, 1.0)
            var radius: float = lerpf(170, 22, progress)
            var angle: float = mote * 2.4 + elapsed * 0.9 + progress * 2.0
            var point: Vector2 = center + Vector2.from_angle(angle) * radius
            draw_circle(point, 1.0 + progress, Color(0.76, 0.58, 1.0, progress * 0.7))
        draw_circle(center, 18, Color("03020b"))
        draw_arc(center, 19, 0, TAU, 60, Color("d4a3ff"), 2, true)
        draw_string(ThemeDB.fallback_font, center + Vector2(-30, 69), "SINGULARITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ba91de"))
    for alien in aliens:
        var center: Vector2 = alien["position"]
        draw_circle(center, 34, Color(0.7, 0.2, 0.4, 0.06))
        SPRITES.ship(self, 2, Rect2(center - Vector2(29, 15), Vector2(58, 30)))

    for asteroid in asteroids:
        var center: Vector2 = asteroid["position"]
        var points := PackedVector2Array()
        for edge in range(9):
            points.append(center + Vector2.from_angle(edge * TAU / 8) * (23 + edge % 3 * 3))
        draw_colored_polygon(points, Color("756e70"))
        draw_polyline(points, Color("c1a297"), 1.5, true)
        draw_circle(center + Vector2(-7, -4), 7, Color("514c58"))
    for gate in gates:
        var center: Vector2 = gate["position"]
        draw_rect(Rect2(center - Vector2(9, 48), Vector2(18, 96)), Color("6f7c84"))
        for stripe in range(6):
            draw_line(center + Vector2(-6, -39 + stripe * 16), center + Vector2(6, -31 + stripe * 16), Color("edbf70"), 4)
        draw_line(center + Vector2(0, -100), center + Vector2(0, -55), Color(0.8, 0.6, 0.3, 0.15), 1)
        draw_line(center + Vector2(0, 55), center + Vector2(0, 100), Color(0.8, 0.6, 0.3, 0.15), 1)
    for drone in drones:
        var center: Vector2 = drone["position"]
        SPRITES.ship(self, 3, Rect2(center - Vector2(22, 24), Vector2(44, 48)))
    for mine in mines:
        var center: Vector2 = mine["position"]
        draw_arc(center, 35, 0, TAU, 40, Color(0.95, 0.4, 0.3, 0.15), 1, true)
        for spike in range(8):
            var direction := Vector2.from_angle(spike * TAU / 8)
            draw_line(center + direction * 9, center + direction * 18, Color("b56c6c"), 3, true)
        draw_circle(center, 10, Color("69394e"))
        draw_circle(center, 3.0 + sin(elapsed * 5), Color("ffac88"))
    for meteor in meteors:
        var center: Vector2 = meteor["position"]
        draw_line(center - Vector2(23, 46), center, Color(0.95, 0.5, 0.25, 0.12), 12, true)
        draw_line(center - Vector2(15, 30), center, Color("a76d43"), 4, true)
        draw_circle(center, 12, Color("d99c65"))
        draw_circle(center + Vector2(2, 2), 8, Color("726271"))
    for beam in beams:
        var center: Vector2 = beam["position"]
        for side in [-1, 1]:
            draw_rect(Rect2(center + Vector2(side * 96 - 6, -13), Vector2(12, 26)), Color("526b79"))
        if bool(beam["active"]):
            draw_line(center - Vector2(96, 0), center + Vector2(96, 0), Color(0.4, 0.8, 1.0, 0.15), 12, true)
            draw_line(center - Vector2(96, 0), center + Vector2(96, 0), Color("9decff"), 3, true)
        else:
            for dash in range(12):
                draw_line(center + Vector2(-90 + dash * 16, 0), center + Vector2(-82 + dash * 16, 0), Color(0.4, 0.8, 1.0, 0.2), 1, true)
