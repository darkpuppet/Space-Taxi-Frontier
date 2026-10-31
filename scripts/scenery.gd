extends RefCounted
## Authored environment compositions. All scenery is background-only.
const W: float = 2400.0
const H: float = 680.0

static func poly(canvas: Node2D, points: Array, color: Color) -> void:
    canvas.draw_colored_polygon(PackedVector2Array(points), color)

static func ellipse(canvas: Node2D, center: Vector2, radius: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for i in range(65):
        var angle: float = float(i) / 64.0 * TAU
        points.append(center + Vector2(cos(angle), sin(angle)) * radius)
    canvas.draw_colored_polygon(points, color)

static func ridge(canvas: Node2D, color: Color, height: float, amplitude: float, seed_value: float) -> void:
    var points := PackedVector2Array([Vector2(0, H)])
    for i in range(81):
        var x: float = i * 30.0
        var y: float = height + sin(x * 0.004 + seed_value) * amplitude + sin(x * 0.013 + seed_value * 2) * amplitude * 0.32
        points.append(Vector2(x, y))
    points.append(Vector2(W, H))
    canvas.draw_colored_polygon(points, color)

static func orb(canvas: Node2D, center: Vector2, radius: float, color: Color) -> void:
    for ring in range(7, 0, -1):
        canvas.draw_circle(center, radius + ring * 5, Color(color.r, color.g, color.b, 0.018 * (8 - ring)))
    canvas.draw_circle(center, radius, color)

static func paint(canvas: Node2D, data: Dictionary, time: float, world_height: float = 720.0) -> void:
    var index: int = data.get("index", 0)
    preload("res://scripts/bitmap_art.gd").paint(canvas, index, Vector2(W, world_height))
    return

static func procedural_fallback(canvas: Node2D, data: Dictionary, time: float, world_height: float = 720.0) -> void:
    var index: int = data.get("index", 0)
    var bg: Color = data.get("color", Color("102431"))
    canvas.draw_rect(Rect2(0, 0, W, world_height), bg.darkened(0.4))
    for band in range(int(world_height / 30.0)):
        canvas.draw_rect(Rect2(0, band * 30, W, 30), Color(bg.r, bg.g, bg.b, minf(0.85, float(band) / (world_height / 25.0))))
    for i in range(230):
        var star := Vector2(float((i * 337 + 67) % 2400), float((i * 149 + 39) % int(world_height - 90)))
        canvas.draw_circle(star, 0.8 + (i % 3) * 0.25, Color(0.72, 0.83, 0.96, 0.2 + sin(time * 0.4 + i) * 0.12))
    canvas.draw_set_transform(Vector2(0, world_height - 720))
    match index:
        0: # Academy station: enclosed observation hangar, no physical obstacles.
            orb(canvas, Vector2(1560, 280), 140, Color("193c54"))
            canvas.draw_arc(Vector2(1560, 280), 148, -1.5, 1.2, 90, Color("54879b"), 2, true)
            for i in range(7):
                var x: float = i * 400.0
                canvas.draw_rect(Rect2(x, 0, 18, H), Color("192d3a"))
                canvas.draw_line(Vector2(x + 18, 0), Vector2(x + 18, H), Color("305467"), 2)
                canvas.draw_rect(Rect2(x + 54, 344, 220, 3), Color("1d3c4e"))
            canvas.draw_rect(Rect2(0, 310, W, 10), Color("172f3d"))
            canvas.draw_string(ThemeDB.fallback_font, Vector2(470, 265), "FRONTIER FLIGHT ACADEMY", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("36596a"))
        1: # Desert world and mesa formations.
            orb(canvas, Vector2(1580, 190), 66, Color("bd8056"))
            ridge(canvas, Color("5b3d32"), 450, 45, 1.0)
            for i in range(8):
                var x: float = i * 330
                poly(canvas, [Vector2(x, 610), Vector2(x + 25, 370 + i % 3 * 35), Vector2(x + 105, 370 + i % 3 * 35), Vector2(x + 145, 610)], Color("694632"))
            ridge(canvas, Color("392b27"), 565, 32, 3.0)
        2: # Ice spires and an animated aurora.
            for band in range(4):
                var points := PackedVector2Array()
                for i in range(65):
                    points.append(Vector2(i * 38, 180 + sin(i * 0.14 + time * 0.15 + band * 0.4) * 42 + band * 14))
                canvas.draw_polyline(points, Color(0.22, 0.85, 0.76, 0.09 - band * 0.015), 12, true)
            for i in range(17):
                var x: float = i * 154
                var top: float = 390 + (i * 37 % 140)
                poly(canvas, [Vector2(x, H), Vector2(x + 50, top), Vector2(x + 100, H)], Color("31576b"))
                poly(canvas, [Vector2(x + 50, top), Vector2(x + 70, H), Vector2(x + 100, H)], Color("223c54"))
        3: # Copper canyon with natural stone bridges.
            ridge(canvas, Color("543a34"), 420, 100, 4.0)
            for i in range(9):
                var x: float = i * 290
                var top: float = 250 + i % 3 * 65
                poly(canvas, [Vector2(x - 30, H), Vector2(x + 15, top), Vector2(x + 70, top - 15), Vector2(x + 110, H)], Color("67493b"))
                canvas.draw_line(Vector2(x + 25, top + 32), Vector2(x + 75, H), Color("80533e"), 3)
                if i % 2 == 0:
                    poly(canvas, [Vector2(x + 65, top + 100), Vector2(x + 315, top + 180), Vector2(x + 315, top + 198), Vector2(x + 65, top + 120)], Color("46312e"))
        4: # Alien fungal forest.
            ridge(canvas, Color("203c3a"), 500, 65, 5.0)
            for i in range(16):
                var x: float = i * 164
                var top: float = 370 + i * 43 % 170
                canvas.draw_line(Vector2(x, H), Vector2(x + 15, top), Color("345344"), 12, true)
                ellipse(canvas, Vector2(x + 15, top), Vector2(58, 22), Color("397765"))
                canvas.draw_circle(Vector2(x + 15, top - 8), 10, Color("76ae7c"))
                for dot in range(4):
                    canvas.draw_circle(Vector2(x - 20 + dot * 20, top + 2), 3, Color("73cfa0"))
        5: # Neon metropolis with diagonal rain.
            city(canvas, Color("251d3b"), Color("a55a9d"), true)
            for i in range(80):
                var x: float = float(i * 97 % 2400)
                var y: float = fposmod(i * 53 + time * 45, 680)
                canvas.draw_line(Vector2(x, y), Vector2(x - 9, y + 22), Color(0.5, 0.65, 0.9, 0.08), 1, true)
        6: # Twin suns and terraced moon terrain.
            orb(canvas, Vector2(1500, 150), 48, Color("cd956b"))
            orb(canvas, Vector2(1605, 170), 30, Color("7a9bb3"))
            for i in range(12):
                var x: float = i * 220
                var top: float = 480 + (i % 4) * 30
                canvas.draw_rect(Rect2(x, top, 170, H - top), Color("3c4357"))
                canvas.draw_line(Vector2(x, top), Vector2(x + 170, top), Color("626579"), 2)
        7: # Hive world with giant honeycomb architecture.
            for row in range(5):
                for col in range(16):
                    var center := Vector2(col * 165 + (row % 2) * 82, row * 140 + 160)
                    var points := PackedVector2Array()
                    for edge in range(7):
                        points.append(center + Vector2(cos(edge * TAU / 6), sin(edge * TAU / 6)) * 78)
                    canvas.draw_polyline(points, Color("314c45"), 4, true)
                    if (row + col) % 4 == 0:
                        canvas.draw_circle(center, 12, Color("49624c"))
        8: # Deep space, distant accretion disk.
            ellipse(canvas, Vector2(1660, 300), Vector2(270, 52), Color("352347"))
            ellipse(canvas, Vector2(1660, 300), Vector2(230, 34), Color("583956"))
            canvas.draw_circle(Vector2(1660, 300), 93, Color("120f22"))
            canvas.draw_arc(Vector2(1660, 300), 100, PI, TAU, 90, Color("8e647f"), 3, true)
        9: # Orbital wheel station and cargo gantries.
            var center := Vector2(1570, 330)
            canvas.draw_arc(center, 235, 0, TAU, 120, Color("2d465e"), 18, true)
            canvas.draw_arc(center, 215, 0, TAU, 120, Color("4c6477"), 2, true)
            for spoke in range(12):
                var direction := Vector2.from_angle(spoke * TAU / 12)
                canvas.draw_line(center + direction * 60, center + direction * 235, Color("304758"), 10, true)
            canvas.draw_circle(center, 62, Color("26394b"))
            city(canvas, Color("1c2c3b"), Color("426b83"), false)
        10: # Binary dusk, layered purple ridges and sunset.
            orb(canvas, Vector2(1240, 440), 170, Color("784355"))
            ridge(canvas, Color("50334c"), 450, 70, 11)
            ridge(canvas, Color("372a43"), 530, 42, 7)
            ridge(canvas, Color("262337"), 600, 25, 9)
        11: # Asteroid belt and industrial mining arms.
            for i in range(35):
                var center := Vector2(float(i * 281 % 2400), float(140 + i * 71 % 450))
                var points := PackedVector2Array()
                for edge in range(8):
                    points.append(center + Vector2.from_angle(edge * TAU / 7) * (15 + (i + edge) % 3 * 5))
                canvas.draw_colored_polygon(points, Color("333b46"))
            for i in range(5):
                var x: float = 350 + i * 480
                canvas.draw_line(Vector2(x, H), Vector2(x, 470), Color("35454c"), 12)
                canvas.draw_line(Vector2(x, 470), Vector2(x + 90, 420), Color("516063"), 5)
        12: # A bright distant spatial rift.
            for band in range(8, 0, -1):
                var points := PackedVector2Array()
                for i in range(20):
                    points.append(Vector2(1250 + sin(i * 1.5) * 40 + sin(i * 0.4) * 75, i * 37))
                canvas.draw_polyline(points, Color(0.62, 0.36, 0.9, 0.035), band * 10, true)
            ridge(canvas, Color("382b4d"), 570, 50, 12)
        13: # Volcanic surface and glowing fissures.
            ridge(canvas, Color("4b2b30"), 420, 90, 14)
            ridge(canvas, Color("292330"), 550, 45, 15)
            for i in range(12):
                var x: float = i * 230
                poly(canvas, [Vector2(x, H), Vector2(x + 55, 575), Vector2(x + 70, 582), Vector2(x + 24, H)], Color("a24c35"))
                canvas.draw_line(Vector2(x + 10, H), Vector2(x + 61, 580), Color("d28b48"), 2)
        14: # Floating gardens and luminous alien trees.
            for i in range(13):
                var x: float = i * 210
                var y: float = 410 + i * 37 % 170
                poly(canvas, [Vector2(x - 55, y), Vector2(x + 65, y), Vector2(x + 5, y + 65)], Color("3e4d4a"))
                ellipse(canvas, Vector2(x + 5, y), Vector2(61, 10), Color("56795d"))
                canvas.draw_line(Vector2(x, y), Vector2(x + 5, y - 65), Color("5b6d64"), 5)
                canvas.draw_circle(Vector2(x + 5, y - 69), 23, Color("6d5b83"))
                canvas.draw_circle(Vector2(x + 12, y - 76), 15, Color("927998"))
        15: # Night ocean and coastal watchtowers.
            orb(canvas, Vector2(1680, 180), 60, Color("526d88"))
            canvas.draw_circle(Vector2(1700, 168), 56, bg.darkened(0.3))
            for line in range(12):
                var y: float = 475 + line * 18
                canvas.draw_line(Vector2(0, y), Vector2(W, y + sin(time + line) * 3), Color(0.2, 0.45, 0.6, 0.12), 1)
            for i in range(8):
                var x: float = i * 340
                poly(canvas, [Vector2(x, H), Vector2(x + 25, 430), Vector2(x + 50, H)], Color("243c50"))
                canvas.draw_circle(Vector2(x + 25, 430), 5, Color("709aaf"))
        16: # Violet nebula with illuminated gas clouds.
            for i in range(14):
                var center := Vector2(i * 190, 280 + sin(i * 0.8) * 150)
                ellipse(canvas, center, Vector2(250, 65 + i % 3 * 20), Color(0.4, 0.2, 0.55, 0.07))
                ellipse(canvas, center + Vector2(20, 35), Vector2(200, 30), Color(0.25, 0.5, 0.65, 0.06))
        17: # Derelict outer-rim station, crooked hull panels.
            for i in range(13):
                var x: float = i * 210
                poly(canvas, [Vector2(x, H), Vector2(x + 10, 400 + i % 3 * 60), Vector2(x + 125, 430 + i % 3 * 40), Vector2(x + 170, H)], Color("3d3b3c"))
                canvas.draw_line(Vector2(x + 30, H), Vector2(x + 40, 470), Color("655044"), 3)
                for mark in range(3):
                    canvas.draw_line(Vector2(x + 60 + mark * 15, 540), Vector2(x + 70 + mark * 15, 560), Color("8a6c47"), 3)
            canvas.draw_line(Vector2(0, 170), Vector2(W, 320), Color("343b43"), 12)
        18: # Total eclipse over a low jagged horizon.
            orb(canvas, Vector2(1450, 260), 118, Color("bb735e"))
            canvas.draw_circle(Vector2(1453, 257), 116, Color("1c1727"))
            canvas.draw_arc(Vector2(1450, 260), 125, 0, TAU, 100, Color("784e5b"), 1, true)
            ridge(canvas, Color("3c2f41"), 520, 55, 19)
            ridge(canvas, Color("252333"), 610, 23, 20)
        19: # Frontier gateway and the final colony.
            var center := Vector2(1580, 300)
            for ring in range(4):
                canvas.draw_arc(center, 160 + ring * 12, -2.8, 0.4, 110, Color("756c58"), 3, true)
            for i in range(16):
                var point: Vector2 = center + Vector2.from_angle(i * TAU / 16) * 192
                canvas.draw_circle(point, 4, Color("c5ab73"))
            city(canvas, Color("2c3d45"), Color("9a9877"), false)
    # Foreground tint anchors terminals without repeating the same skyline everywhere.
    canvas.draw_rect(Rect2(0, H, W, 40), bg.darkened(0.35))
    canvas.draw_set_transform(Vector2.ZERO)

static func city(canvas: Node2D, color: Color, light: Color, neon: bool) -> void:
    for i in range(24):
        var x: float = i * 108
        var height: float = 70 + i * 53 % 190
        canvas.draw_rect(Rect2(x, H - height, 82, height), color)
        if neon and i % 3 == 0:
            canvas.draw_rect(Rect2(x + 8, H - height + 12, 5, height * 0.6), light)
        for row in range(4):
            for col in range(4):
                if (i + col + row) % 3 != 0:
                    canvas.draw_rect(Rect2(x + 18 + col * 14, H - height + 18 + row * 21, 4, 7), Color(light.r, light.g, light.b, 0.35))
