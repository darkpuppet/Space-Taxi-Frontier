extends Control
const WORLD = preload("res://scripts/world.gd")
var taxi_position := Vector2.ZERO
var pads: Array = []
var hazards: Array = []
var fares: Array = []
var gate_position := Vector2(-1, -1)
var target_id: int = 1
const MAP := Rect2(18, 79, 168, 112)

func panel(rect: Rect2, fill: Color, border: Color, radius: int = 8) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    draw_style_box(style, rect)

func text_at(position: Vector2, text: String, font_size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func point(position: Vector2) -> Vector2:
    var normalized := Vector2(position.x / WORLD.WIDTH, position.y / WORLD.HEIGHT).clamp(Vector2.ZERO, Vector2.ONE)
    return MAP.position + Vector2(8, 8) + normalized * (MAP.size - Vector2(16, 16))

func _draw() -> void:
    # A short cradle connects the portrait handset to the dashboard lip.
    panel(Rect2(77, 243, 50, 29), Color("17242d"), Color("8c7753"), 4)
    panel(Rect2(51, 263, 102, 8), Color("263b44"), Color("8c7753"), 3)
    panel(Rect2(4, 5, 200, 253), Color("00000070"), Color("00000000"), 18)
    panel(Rect2(0, 0, 200, 253), Color("101a23"), Color("8c9da0"), 18)
    panel(Rect2(8, 8, 184, 237), Color("0b242d"), Color("304b58"), 12)
    panel(Rect2(77, 9, 46, 8), Color("080f17"), Color("080f17"), 4)
    text_at(Vector2(19, 29), "FRONTIER", 9, Color("7d9aa9"))
    for bar in range(4):
        draw_rect(Rect2(153 + bar * 5, 27 - bar * 2, 3, 3 + bar * 2), Color("73e0d3"))
    text_at(Vector2(18, 51), "DISPATCH / MAP", 13, Color("73e0d3"))
    text_at(Vector2(18, 68), "LIVE SECTOR TRACKING", 9, Color("7d9aa9"))
    panel(MAP, Color("0a1a24"), Color("304b58"), 4)
    for line in range(1, 4):
        var x: float = MAP.position.x + MAP.size.x * line / 4.0
        var y: float = MAP.position.y + MAP.size.y * line / 4.0
        draw_line(Vector2(x, MAP.position.y), Vector2(x, MAP.end.y), Color("17333e"))
        draw_line(Vector2(MAP.position.x, y), Vector2(MAP.end.x, y), Color("17333e"))
    var target := gate_position
    if gate_position.x < 0:
        for pad in pads:
            if int(pad["id"]) == target_id:
                target = Vector2(pad["x"], pad["y"])
                break
    if target.x >= 0:
        draw_dashed_line(point(taxi_position), point(target), Color("487a7e"), 1, 4)
    text_at(Vector2(18, 211), "STAR GATE" if gate_position.x >= 0 else "ROUTE / PAD %02d" % target_id, 12, Color("ffc76b"))
    var distance: int = int(WORLD.meters(taxi_position.distance_to(target))) if target.x >= 0 else 0
    text_at(Vector2(18, 229), "%04d m   /   %d WAITING" % [distance, fares.size()], 10, Color("a6cedb"))
    draw_line(Vector2(78, 239), Vector2(122, 239), Color("527685"), 3, true)
    for pad in pads:
        var pos: Vector2 = point(Vector2(pad["x"], pad["y"]))
        var color: Color = Color("ffc76b") if int(pad["id"]) == target_id else Color("527685")
        var upgrade_dock: bool = pad.get("services", []).has("upgrades")
        if upgrade_dock:
            color = Color("c896ff")
            draw_rect(Rect2(pos - Vector2(8, 4), Vector2(16, 8)), color, false, 1.5)
        draw_line(pos - Vector2(7, 0), pos + Vector2(7, 0), color, 2)
        draw_string(ThemeDB.fallback_font, pos + Vector2(9, 3), "UP" if upgrade_dock else str(pad["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
    for hazard in hazards:
        draw_circle(point(hazard["position"]), 2.0, Color("dd8abf"))
    for fare in fares:
        var pad: Dictionary = pads[int(fare["source"]) - 1]
        draw_circle(point(Vector2(pad["x"], pad["y"])) - Vector2(0, 5), 3, Color("ffc76b") if float(fare["patience"]) > 15 else Color("ff806e"))
    var taxi: Vector2 = point(taxi_position)
    draw_colored_polygon(PackedVector2Array([taxi + Vector2(-4, -3), taxi + Vector2(4, -3), taxi + Vector2(0, 4)]), Color("73e0d3"))
    if gate_position.x >= 0:
        draw_arc(point(gate_position), 6, 0, TAU, 24, Color("79e5ed"), 2, true)
