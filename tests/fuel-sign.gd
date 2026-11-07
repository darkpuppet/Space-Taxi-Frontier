extends SceneTree
const SIGN = preload("res://scripts/fuel_sign.gd")
var failures: int = 0
var price: int = 2

func check(value: bool, label: String) -> void:
    if not value:
        failures += 1
        push_error("FAIL: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(320, 240)
    var canvas := Node2D.new()
    root.add_child(canvas)
    canvas.draw.connect(func() -> void: SIGN.draw(canvas, Rect2(60, 20, 200, 200), price))
    var baseline: Image
    var readouts: Dictionary = {}
    var outside_changes: int = 0
    for value in range(2, 11):
        price = value
        canvas.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        var rendered: Image = root.get_texture().get_image()
        var display := Rect2i(90, 88, 136, 40)
        var digest: String = rendered.get_region(display).get_data().hex_encode().sha256_text()
        check(not readouts.has(digest), "Each market price has a distinct digital readout")
        readouts[digest] = true
        if baseline == null:
            baseline = rendered
        else:
            for y in range(240):
                for x in range(320):
                    if not display.has_point(Vector2i(x, y)) and rendered.get_pixel(x, y) != baseline.get_pixel(x, y):
                        outside_changes += 1
        if value in [2, 10]:
            rendered.save_png("res://.development/fuel-sign-%02d.png" % value)
    check(outside_changes == 0, "Price updates change only the sign's display window")
    check(SIGN.ART.get_image().get_pixel(0, 0).a < 0.05, "Sign sprite has a transparent backdrop")
    canvas.free()
    print("Fuel sign: 11 checks, %d failures" % failures)
    quit(1 if failures else 0)
