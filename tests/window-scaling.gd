extends SceneTree
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    if value:
        print("PASS: " + description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_resize_test.cfg"
    root.add_child(game)
    await process_frame
    var sizes: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1600, 900), Vector2i(1500, 750), Vector2i(900, 1000), Vector2i(800, 600), Vector2i(1280, 720)]
    for size in sizes:
        root.size = size
        await process_frame
        await RenderingServer.frame_post_draw
        var transform: Transform2D = root.get_stretch_transform()
        var scale: Vector2 = transform.get_scale()
        var expected: float = minf(float(root.size.x) / 1280, float(root.size.y) / 720)
        print("RESIZE: %s / actual %s / scale %s / expected %.4f / logical %s" % [size, root.size, scale, expected, root.get_visible_rect().size])
        check(absf(scale.x - scale.y) <= 1.0 / 720.0 and absf(scale.x - expected) < 0.002, "Window scales the picture uniformly to fit")
        check(root.get_visible_rect().size.is_equal_approx(Vector2(1280, 720)), "World and HUD keep the 16:9 logical viewport")
        check(game.overlay.get_global_rect().end.x <= 1281 and game.overlay.get_global_rect().end.y <= 721, "Main menu remains inside the scaled screen")
        if size == Vector2i(900, 1000):
            root.get_texture().get_image().save_png("res://tests/window-portrait.png")
    check(not root.unresizable, "Game window permits resizing")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    print("Window resize and aspect ratio: %d failures" % failures)
    quit(0 if failures == 0 else 1)
