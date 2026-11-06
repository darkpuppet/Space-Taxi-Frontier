extends Label
## Each clipped drum rolls toward its next numeral when the value changes.
const ART = preload("res://scripts/dashboard_art.gd")
var digits: int = 6
var decimal_places: int = 0
var currency: bool = false
const ROLL_SECONDS: float = 0.45
const DRUM_COLOR := Color("080a0b")
const NUMBER_COLOR := Color("f4f5f1")
var previous: String = ""
var current: String = ""
var roll: float = 1.0
var direction: int = 1
var drums: Array[Control] = []
var housing: Texture2D

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_color_override("font_color", Color.TRANSPARENT)
    custom_minimum_size = Vector2(digits * 18 + 20 + (6 if decimal_places > 0 else 0) + (18 if currency else 0), 48)
    housing = ART.texture(ART.Part.COUNTER)
    for index in range(digits):
        var drum := Control.new()
        drum.clip_contents = true
        drum.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(drum)
        drum.draw.connect(_draw_drum.bind(index, drum))
        drums.append(drum)
    resized.connect(_layout_drums)
    _layout_drums()

func _layout_drums() -> void:
    for index in range(drums.size()):
        var decimal_gap: int = 6 if decimal_places > 0 and index >= digits - decimal_places else 0
        drums[index].position = Vector2(10 + index * 18 + decimal_gap + (18 if currency else 0), 8)
        drums[index].size = Vector2(17, 30)
    queue_redraw()

func _process(dt: float) -> void:
    var next: String = text.trim_prefix("₡").trim_suffix(" CR").trim_suffix(" km").trim_suffix(" m").strip_edges().replace(".", "")
    if next.begins_with("-"):
        next = "-" + next.substr(1).pad_zeros(digits - 1)
    else:
        next = next.pad_zeros(digits)
    if next.length() > digits:
        next = "#".repeat(digits)
    roll = minf(1.0, roll + dt / ROLL_SECONDS)
    if current == "":
        previous = next
        current = next
    elif next != current and roll >= 1.0:
        previous = current
        current = next
        direction = 1 if absi(current.to_int()) >= absi(previous.to_int()) else -1
        roll = 0.0
    for drum in drums:
        drum.queue_redraw()
    queue_redraw()

func drum_state(index: int) -> Dictionary:
    var old: String = previous[index]
    var target: String = current[index]
    if old == target or roll >= 1.0:
        return {"from": target, "to": target, "fraction": 0.0}
    if old.is_valid_int() and target.is_valid_int():
        var start: int = old.to_int()
        var finish: int = target.to_int()
        var steps: int = posmod((finish - start) * direction, 10)
        var travel: float = smoothstep(0.0, 1.0, roll) * steps
        var digit: int = posmod(start + direction * floori(travel), 10)
        return {"from": str(digit), "to": str(posmod(digit + direction, 10)), "fraction": fmod(travel, 1.0)}
    return {"from": old, "to": target, "fraction": smoothstep(0.0, 1.0, roll)}

func _draw_drum(index: int, drum: Control) -> void:
    if current.length() != digits:
        return
    drum.draw_rect(Rect2(Vector2.ZERO, drum.size), DRUM_COLOR)
    var font: Font = ThemeDB.fallback_font
    var state: Dictionary = drum_state(index)
    var offset: float = 30.0 * float(state["fraction"]) * direction
    drum.draw_string(font, Vector2(0, 23 - offset), state["from"], HORIZONTAL_ALIGNMENT_CENTER, 17, 22, NUMBER_COLOR)
    if float(state["fraction"]) > 0:
        drum.draw_string(font, Vector2(0, 23 - offset + 30 * direction), state["to"], HORIZONTAL_ALIGNMENT_CENTER, 17, 22, NUMBER_COLOR)
    drum.draw_rect(Rect2(0, 0, 17, 4), Color("00000065"))
    drum.draw_rect(Rect2(0, 26, 17, 4), Color("00000065"))
    drum.draw_line(Vector2(0, 1), Vector2(17, 1), Color("ffffff12"))

func _draw() -> void:
    if housing != null:
        draw_texture_rect(housing, Rect2(0, 0, custom_minimum_size.x, 48), false)
    if decimal_places > 0:
        draw_circle(Vector2(10 + (digits - decimal_places) * 18 + 2, 34), 1.5, NUMBER_COLOR)
    if currency:
        preload("res://scripts/credit_mark.gd").draw(self, Vector2(17, 23), 18, NUMBER_COLOR)
