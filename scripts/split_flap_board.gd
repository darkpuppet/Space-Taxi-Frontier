extends Control
## A native UI departure-board display; score data stays untouched.
const CELL := Vector2(14, 25)
const DESIGN_SIZE := Vector2(664, 333)
const ROW_PITCH: float = 30.0
const STEP_TIME: float = 0.065
const LETTERS: String = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.'/?"
const NUMBERS: String = " 0123456789-"
const CREDIT_GLYPH: String = "\uE000"
const COLUMNS: Array[Dictionary] = [
    {"label": "#", "width": 2, "number": true},
    {"label": "PILOT", "width": 18, "number": false},
    {"label": "CREDITS", "width": 9, "number": true},
    {"label": "FARES", "width": 5, "number": true},
    {"label": "LAST LEVEL", "width": 8, "number": true}
]
var cells: Array[Dictionary] = []
var headings: Array[Dictionary] = []
var elapsed: float = 0.0
var duration: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = DESIGN_SIZE
    resized.connect(queue_redraw)

func set_entries(entries: Array[Dictionary]) -> void:
    cells.clear()
    headings.clear()
    elapsed = 0.0
    duration = 0.0
    for row in range(10):
        var occupied: bool = row < entries.size()
        var values: Array[String] = [str(row + 1), "-", "-", "-", "-"]
        if occupied:
            var entry: Dictionary = entries[row]
            values = [str(row + 1), str(entry["pilot"]).to_upper(), str(entry["credits"]), str(entry["fares"]), "%02d" % entry["level"]]
        var x: float = 8.0
        var serial: int = 0
        for column in range(COLUMNS.size()):
            var spec: Dictionary = COLUMNS[column]
            var width: int = int(spec["width"])
            var text: String = values[column]
            if column == 2:
                if text.length() > width - 1:
                    text = "#".repeat(width - 1)
                text = (CREDIT_GLYPH if occupied else " ") + text.lpad(width - 1)
            elif text.length() > width:
                # Numeric overflow is explicit rather than silently dropping digits.
                text = "#".repeat(width) if spec["number"] else text.left(width)
            text = text.lpad(width) if spec["number"] else text.rpad(width)
            if row == 0:
                headings.append({"text": spec["label"], "x": x, "width": width * CELL.x})
            for character in range(width):
                var target: String = text[character]
                var cycles: int = 5 + (row * 3 + serial) % 8 if occupied and target != " " else 0
                var delay: float = row * 0.13 + serial * 0.012
                var alphabet: String = (NUMBERS + CREDIT_GLYPH) if target == CREDIT_GLYPH else (NUMBERS if spec["number"] else LETTERS)
                cells.append({"target": target, "alphabet": alphabet, "cycles": cycles, "delay": delay, "position": Vector2(x, 25 + row * ROW_PITCH)})
                if cycles > 0:
                    duration = maxf(duration, delay + cycles * STEP_TIME)
                x += CELL.x
                serial += 1
            x += 10.0
    queue_redraw()

func settled() -> bool:
    return elapsed >= duration

func cell_state(cell: Dictionary) -> Dictionary:
    var cycles: int = int(cell["cycles"])
    if cycles > 0 and elapsed < float(cell["delay"]):
        return {"glyph": " ", "scale": 1.0}
    var age: float = maxf(0.0, elapsed - float(cell["delay"]))
    var step: int = int(age / STEP_TIME)
    if cycles == 0 or step >= cycles:
        return {"glyph": cell["target"], "scale": 1.0}
    var alphabet: String = cell["alphabet"]
    var target_index: int = alphabet.find(str(cell["target"]))
    if target_index < 0: target_index = alphabet.length() - 1
    var phase: float = fposmod(age, STEP_TIME) / STEP_TIME
    var glyph_index: int = target_index - cycles + step + (1 if phase >= 0.5 else 0)
    return {"glyph": alphabet[posmod(glyph_index, alphabet.length())], "scale": maxf(0.06, absf(cos(phase * PI)))}

func _process(dt: float) -> void:
    if not is_visible_in_tree() or settled():
        return
    elapsed = minf(duration, elapsed + dt)
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("080e15"))
    var scale: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
    var offset: Vector2 = (size - DESIGN_SIZE * scale) * 0.5
    draw_set_transform(offset, 0, Vector2.ONE * scale)
    var font: Font = ThemeDB.fallback_font
    for label in headings:
        draw_string(font, Vector2(float(label["x"]), 16), str(label["text"]), HORIZONTAL_ALIGNMENT_CENTER, float(label["width"]), 11, Color("73e0d3"))
    for cell in cells:
        var origin: Vector2 = cell["position"]
        var center: Vector2 = origin + CELL * 0.5
        var state: Dictionary = cell_state(cell)
        # The dark recess remains fixed while the two front halves rotate through
        # the hinge. Character compression makes each mechanical flip visible.
        draw_rect(Rect2(origin, CELL - Vector2.ONE), Color("080a0c"))
        draw_set_transform(offset + center * scale, 0, Vector2(scale, scale * float(state["scale"])))
        draw_rect(Rect2(-CELL * 0.5, Vector2(CELL.x - 1, CELL.y * 0.5)), Color("303a45"))
        draw_rect(Rect2(Vector2(-CELL.x * 0.5, 0), Vector2(CELL.x - 1, CELL.y * 0.5 - 1)), Color("212a34"))
        var glyph: String = str(state["glyph"])
        if glyph == CREDIT_GLYPH:
            preload("res://scripts/credit_mark.gd").draw(self, Vector2(-0.5, 0), 16, Color("ebc88b"))
        else:
            var glyph_width: float = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
            var baseline: float = (font.get_ascent(14) - font.get_descent(14)) * 0.5
            draw_string(font, Vector2(-glyph_width * 0.5 - 0.5, baseline), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffe9b5"))
        draw_set_transform(offset, 0, Vector2.ONE * scale)
        draw_line(origin + Vector2(0, CELL.y * 0.5), origin + Vector2(CELL.x - 1, CELL.y * 0.5), Color("080c12"), 1)
        for side in [0, 1]:
            draw_rect(Rect2(origin + Vector2(side * (CELL.x - 3), CELL.y * 0.5 - 1), Vector2(2, 2)), Color("75808b"))
