extends Control
const LIBRARY = preload("res://assets/dialogue/ticker-messages.tres")
const SPEED: float = 75.0
const BADGE_WIDTH: float = 180.0
const GAP_SECONDS: float = 0.65
const PITCH: float = 3.0
## Original 5x7 LED glyphs: each integer encodes one row, leftmost bit first.
const GLYPHS: Dictionary = {
    "A": [14,17,17,31,17,17,17], "B": [30,17,17,30,17,17,30],
    "C": [14,17,16,16,16,17,14], "D": [30,17,17,17,17,17,30],
    "E": [31,16,16,30,16,16,31], "F": [31,16,16,30,16,16,16],
    "G": [14,17,16,23,17,17,15], "H": [17,17,17,31,17,17,17],
    "I": [14,4,4,4,4,4,14], "J": [7,2,2,2,2,18,12],
    "K": [17,18,20,24,20,18,17], "L": [16,16,16,16,16,16,31],
    "M": [17,27,21,21,17,17,17], "N": [17,25,21,19,17,17,17],
    "O": [14,17,17,17,17,17,14], "P": [30,17,17,30,16,16,16],
    "Q": [14,17,17,17,21,18,13], "R": [30,17,17,30,20,18,17],
    "S": [15,16,16,14,1,1,30], "T": [31,4,4,4,4,4,4],
    "U": [17,17,17,17,17,17,14], "V": [17,17,17,17,17,10,4],
    "W": [17,17,17,21,21,21,10], "X": [17,17,10,4,10,17,17],
    "Y": [17,17,10,4,4,4,4], "Z": [31,1,2,4,8,16,31],
    "0": [14,17,19,21,25,17,14], "1": [4,12,4,4,4,4,14],
    "2": [14,17,1,2,4,8,31], "3": [30,1,1,14,1,1,30],
    "4": [2,6,10,18,31,2,2], "5": [31,16,16,30,1,1,30],
    "6": [14,16,16,30,17,17,14], "7": [31,1,2,4,8,8,8],
    "8": [14,17,17,14,17,17,14], "9": [14,17,17,15,1,1,14],
    " ": [0,0,0,0,0,0,0], ".": [0,0,0,0,0,12,12],
    ",": [0,0,0,0,0,4,8], ":": [0,12,12,0,12,12,0],
    ";": [0,12,12,0,4,4,8], "'": [4,4,8,0,0,0,0],
    "-": [0,0,0,31,0,0,0], "/": [1,2,2,4,8,8,16],
    "!": [4,4,4,4,4,0,4], "?": [14,17,1,2,4,0,4],
    "&": [12,18,20,8,21,18,13], "+": [0,4,4,31,4,4,0],
    "(": [2,4,8,8,8,4,2], ")": [8,4,2,2,2,4,8],
    "\"": [10,10,10,0,0,0,0]
}
var messages: Array[String] = []
var widths: Array[float] = []
var dot_patterns: Array[PackedVector2Array] = []
var message_index: int = 0
var offset: float = 0.0
var gap_remaining: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    for phrase in LIBRARY.phrases:
        var line: String = phrase.strip_edges()
        if not line.is_empty():
            messages.append(line)
    if messages.is_empty():
        messages.append("FRONTIER TAXI: We go the extra light-year. The meter does too.")
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for index in range(messages.size() - 1, 0, -1):
        var other: int = rng.randi_range(0, index)
        var swap: String = messages[index]
        messages[index] = messages[other]
        messages[other] = swap
    for line in messages:
        var text: String = line.to_upper().replace("’", "'").replace("—", "-").replace("–", "-")
        var dots := PackedVector2Array()
        for index in range(text.length()):
            var rows: Array = GLYPHS.get(text[index], GLYPHS["?"])
            for row in range(7):
                for column in range(5):
                    if int(rows[row]) & (1 << (4 - column)):
                        dots.append(Vector2((index * 6 + column) * PITCH, row * PITCH))
        dot_patterns.append(dots)
        widths.append(maxf(PITCH, (text.length() * 6 - 1) * PITCH))

func message_right_edge() -> float:
    return floorf(size.x / PITCH) * PITCH - floorf(offset / PITCH) * PITCH + widths[message_index]

func _process(dt: float) -> void:
    # Menus pause the world; this independent UI clock keeps the wire running.
    if not is_visible_in_tree() or messages.is_empty():
        return
    if gap_remaining > 0:
        gap_remaining = maxf(0, gap_remaining - dt)
        if gap_remaining <= 0:
            message_index = (message_index + 1) % messages.size()
            offset = 0
    else:
        offset += SPEED * dt
        if message_right_edge() < BADGE_WIDTH:
            gap_remaining = GAP_SECONDS
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("060c0f"))
    draw_line(Vector2.ZERO, Vector2(size.x, 0), Color("47616b"), 2)
    # Unlit diodes remain visible during the gap, like a physical LED sign.
    for column in range(int((size.x - BADGE_WIDTH) / PITCH)):
        for row in range(7):
            draw_circle(Vector2(BADGE_WIDTH + column * PITCH, 12 + row * PITCH), 0.8, Color("241b12"))
    if not messages.is_empty() and gap_remaining <= 0:
        var x: float = floorf(size.x / PITCH) * PITCH - floorf(offset / PITCH) * PITCH
        for dot in dot_patterns[message_index]:
            var point: Vector2 = Vector2(x, 12) + dot
            if point.x > BADGE_WIDTH + 2 and point.x < size.x - 2:
                draw_circle(point, 2.1, Color(1, 0.46, 0.08, 0.16))
                draw_circle(point, 1.05, Color("ffb84d"))
                draw_circle(point, 0.45, Color("ffe1a0"))
    draw_rect(Rect2(0, 0, BADGE_WIDTH, size.y), Color("10212a"))
    draw_line(Vector2(BADGE_WIDTH, 8), Vector2(BADGE_WIDTH, size.y - 8), Color("73e0d3"), 1)
    draw_circle(Vector2(17, 21), 3, Color("ffb84d"))
    draw_string(ThemeDB.fallback_font, Vector2(30, 26), "DISPATCH WIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("73e0d3"))
