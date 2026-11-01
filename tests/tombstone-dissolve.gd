extends SceneTree
const FX = preload("res://scripts/passenger_accident_fx.gd")
const BITMAP = preload("res://scripts/bitmap_art.gd")
const BACKDROP := Color("101c30")
var failures: int = 0
var stages: Array[float] = [-1, 0.15, 0.3, 0.5, 0.7, 0.9]

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func _paint(canvas: Node2D) -> void:
    canvas.draw_rect(Rect2(0, 0, 960, 260), BACKDROP)
    for index in range(stages.size()):
        BITMAP.sprite(canvas, 0, Rect2(index * 160 + 15, 184, 130, 14))
        canvas.draw_string(ThemeDB.fallback_font, Vector2(index * 160 + 25, 235), "STANDING" if index == 0 else "%.2f s" % stages[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _grave(canvas: Node2D, age: float) -> void:
    var accident: Dictionary = {"position": Vector2.ZERO, "age": 4.0, "color": Color.RED, "alien": false}
    if age >= 0:
        accident["dissolve_age"] = age
    FX.draw(canvas, accident)

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(960, 260)
    await process_frame
    var canvas := Node2D.new()
    root.add_child(canvas)
    canvas.draw.connect(_paint.bind(canvas))
    for index in range(stages.size()):
        var grave := Node2D.new()
        grave.position = Vector2(80 + index * 160, 180)
        grave.scale = Vector2(4, 4)
        canvas.add_child(grave)
        grave.draw.connect(_grave.bind(grave, stages[index]))
    await process_frame
    await RenderingServer.frame_post_draw
    var picture: Image = root.get_texture().get_image()
    var amounts: Array[int] = []
    for index in range(stages.size()):
        var visible: int = 0
        for y in range(50, 182):
            for x in range(index * 160 + 25, index * 160 + 135):
                if not picture.get_pixel(x, y).is_equal_approx(picture.get_pixel(0, 0)):
                    visible += 1
        amounts.append(visible)
    check(amounts[0] > 1000, "Standing tombstone contains visible sprite artwork")
    check(amounts[1] > amounts[2] and amounts[2] > amounts[3] and amounts[3] > amounts[4], "Tombstone progressively dissolves toward the ground")
    check(amounts[3] < amounts[0] / 2, "Most of the grave has sunk by the middle of the dissolve")
    check(amounts[5] == 0, "Completed dissolve leaves no floating sprite or dust")
    for index in range(1, stages.size()):
        for y in range(190, 210):
            for x in range(25, 135):
                var a: Color = picture.get_pixel(x, y)
                var b: Color = picture.get_pixel(x + index * 160, y)
                # Identical atlas samples may round one color step differently
                # at another screen position; visible spill still fails here.
                if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 1.5 / 255.0:
                    check(false, "Dissolve remains clipped above the platform")
                    break
    picture.save_png("res://tests/tombstone-dissolve.png")
    canvas.free()
    print("Tombstone dissolve rendering: %d failures" % failures)
    quit(0 if failures == 0 else 1)
