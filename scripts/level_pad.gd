@tool
extends Marker2D
## Authored landing position and deck width; gameplay consumes this marker's data.
@export_range(1, 5) var pad_id: int = 1
@export var pad_width: float = 240.0
@export var services: Array[String] = []

func as_dictionary() -> Dictionary:
    return {"id": pad_id, "x": position.x, "y": position.y, "width": pad_width, "services": services.duplicate()}

func _process(_dt: float) -> void:
    if Engine.is_editor_hint():
        queue_redraw()

func _draw() -> void:
    if not Engine.is_editor_hint():
        return
    var tint := Color("c896ff") if services.has("fuel") else Color("73e0d3")
    draw_rect(Rect2(-pad_width * 0.5, 0, pad_width, 27), Color(tint, 0.25))
    draw_line(Vector2(-pad_width * 0.5, 0), Vector2(pad_width * 0.5, 0), tint, 3)
    draw_string(ThemeDB.fallback_font, Vector2(-pad_width * 0.5, -8), "PAD %02d" % pad_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, tint)
