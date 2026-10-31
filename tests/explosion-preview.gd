extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_explosion_preview.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game.taxi.position = Vector2(1200, 650)
    game.taxi.landed_on = -1
    game.taxi.velocity = Vector2(220, 50)
    game._process(0.01)
    game.camera.reset_smoothing()
    game.taxi.hull = 0
    game._process(0.01)
    var sheet: Image = Image.create(1280, 800, false, Image.FORMAT_RGB8)
    var previous: float = 0
    var samples: Array[float] = [0.04, 0.18, 0.5, 1.0]
    for index in range(samples.size()):
        game._process(samples[index] - previous)
        previous = samples[index]
        await process_frame
        await RenderingServer.frame_post_draw
        var frame: Image = root.get_texture().get_image().get_region(Rect2i(320, 160, 640, 400))
        frame.convert(Image.FORMAT_RGB8)
        sheet.blit_rect(frame, Rect2i(0, 0, 640, 400), Vector2i((index % 2) * 640, (index / 2) * 400))
    sheet.save_png("res://tests/explosion-preview.png")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    quit()
