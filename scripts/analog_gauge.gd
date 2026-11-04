extends ProgressBar
const ART = preload("res://scripts/dashboard_art.gd")
const FUEL_ICON = preload("res://assets/icons/low-fuel.svg")
const LOW_FUEL_THRESHOLD: float = 20.0
const FLASH_PERIOD: float = 1.0
var warning_clock: float = 0.0
var health: bool = false
var face: Texture2D
var needle: Texture2D

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    show_percentage = false
    add_theme_stylebox_override("background", StyleBoxEmpty.new())
    add_theme_stylebox_override("fill", StyleBoxEmpty.new())
    # Both gauges warn at the low end: empty fuel or depleted health.
    face = ART.texture(ART.Part.FUEL)
    needle = ART.texture(ART.Part.NEEDLE)
    value_changed.connect(func(_value: float) -> void:
        if not low_fuel_active():
            warning_clock = 0.0
        queue_redraw()
    )

func low_fuel_active() -> bool:
    return not health and value < LOW_FUEL_THRESHOLD

func warning_lit() -> bool:
    return low_fuel_active() and warning_clock < FLASH_PERIOD * 0.5

func _process(dt: float) -> void:
    if get_tree().paused or not low_fuel_active():
        return
    warning_clock = fmod(warning_clock + dt, FLASH_PERIOD)
    queue_redraw()

func needle_angle() -> float:
    return deg_to_rad(135.0 + ratio * 270.0)

func _draw() -> void:
    if face == null:
        return
    var diameter: float = minf(size.x, size.y)
    var center := Vector2(size.x * 0.5, diameter * 0.5)
    draw_texture_rect(face, Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), false)
    draw_set_transform(center, needle_angle())
    draw_texture_rect(needle, Rect2(-5, -5, diameter * 0.36, 10), false)
    draw_set_transform(Vector2.ZERO)
    var font: Font = ThemeDB.fallback_font
    var label: String = "HEALTH" if health else "FUEL"
    draw_string(font, Vector2(0, diameter * 0.75), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color("f4f5f1"))
    if low_fuel_active():
        var icon := Rect2(center.x + diameter * 0.10, diameter * 0.52, diameter * 0.15, diameter * 0.18)
        var lit: bool = warning_lit()
        if lit:
            draw_circle(icon.get_center(), diameter * 0.12, Color("ff9b2418"))
        draw_texture_rect(FUEL_ICON, icon, false, Color("ffb347") if lit else Color("46321b"))
