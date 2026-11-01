extends Control
const WORLD = preload("res://scripts/world.gd")
var taxi_position := Vector2.ZERO
var pads: Array = []
var hazards: Array = []
var fares: Array = []
var gate_position := Vector2(-1, -1)
var target_id: int = 1

func point(position: Vector2) -> Vector2:
    return Vector2(position.x / WORLD.WIDTH * 260.0, 24 + position.y / WORLD.HEIGHT * 130.0)

func _draw() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(0, 10), "SECTOR MAP / 2.4 x 1.4 KM", HORIZONTAL_ALIGNMENT_CENTER, 260, 11, Color("7d9aa9"))
    draw_rect(Rect2(0, 20, 260, 136), Color(0.025, 0.06, 0.09, 0.7))
    draw_rect(Rect2(0, 20, 260, 136), Color("304b58"), false, 1)
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
