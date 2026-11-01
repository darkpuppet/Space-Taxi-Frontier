extends SceneTree
const SPRITES = preload("res://scripts/sprites.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func _paint(canvas: Node2D) -> void:
    canvas.draw_rect(Rect2(0, 0, 800, 560), Color("101c30"))
    for row in range(2):
        for variant in range(3):
            var anchor := Vector2(140 + variant * 250, 235 + row * 260)
            canvas.draw_line(anchor + Vector2(-65, 1), anchor + Vector2(65, 1), Color("57c5d0"), 2)

func _draw_person(canvas: Node2D, variant: int, clock: float) -> void:
    SPRITES.impatient_rider(canvas, Vector2.ZERO, variant, clock)

func _differences(image: Image, area: Rect2i) -> int:
    var count: int = 0
    for y in range(area.position.y, area.end.y):
        for x in range(area.position.x, area.end.x):
            if image.get_pixel(x, y) != image.get_pixel(x, y + 260):
                count += 1
    return count

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(800, 560)
    await process_frame
    var canvas := Node2D.new()
    root.add_child(canvas)
    canvas.draw.connect(_paint.bind(canvas))
    for row in range(2):
        for variant in range(3):
            var person := Node2D.new()
            person.position = Vector2(140 + variant * 250, 235 + row * 260)
            person.scale = Vector2(4, 4)
            canvas.add_child(person)
            person.draw.connect(_draw_person.bind(person, variant, 0.6 if row == 0 else 0.105))
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    for variant in range(3):
        var x: int = 140 + variant * 250
        check(_differences(image, Rect2i(x - 70, 55, 140, 140)) == 0, "Impatient passenger body stays still")
        check(_differences(image, Rect2i(x - 65, 205, 50, 28)) == 0, "Supporting foot stays planted")
        check(_differences(image, Rect2i(x, 205, 65, 29)) > 20, "Every passenger design visibly taps a boot")
    check(is_zero_approx(SPRITES.foot_tap_angle(0.6)), "Tap includes a rest with feet flat")
    check(absf(SPRITES.foot_tap_angle(0.105) - SPRITES.foot_tap_angle(1.155)) < 0.001, "Double tap loops smoothly")
    image.save_png("res://tests/impatient-sprites.png")
    canvas.free()
    print("Impatient sprite rendering: 11 checks, %d failures" % failures)
    quit(0 if failures == 0 else 1)
