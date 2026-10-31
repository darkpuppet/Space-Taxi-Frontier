extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_boarding_preview.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var pickup: int = game.source_pad
    var pad: Dictionary = game.pads[pickup - 1]
    game.taxi.position = Vector2(float(pad["x"]) - 65, float(pad["y"]) - 21)
    game.taxi.landed_on = pickup
    game._on_landed(pickup)
    game._process(0.001)
    game.camera.reset_smoothing()
    var sheet: Image = Image.create(880, 360, false, Image.FORMAT_RGB8)
    var previous: int = 0
    var samples: Array[int] = [0, 25, 55, 110]
    for index in range(samples.size()):
        for step in range(samples[index] - previous):
            game._process(1.0 / 60)
        previous = samples[index]
        await process_frame
        await RenderingServer.frame_post_draw
        var frame: Image = root.get_texture().get_image().get_region(Rect2i(490, 280, 440, 180))
        frame.convert(Image.FORMAT_RGB8)
        sheet.blit_rect(frame, Rect2i(0, 0, 440, 180), Vector2i((index % 2) * 440, (index / 2) * 180))
    sheet.save_png("res://tests/boarding-preview.png")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    quit()
