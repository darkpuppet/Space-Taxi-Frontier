extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_black_hole_animation_preview.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.level = 8
    game._start_level()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    for child in game.hud.get_children():
        if child is CanvasItem:
            child.hide()
    var center: Vector2 = game.sector.holes[0]["position"]
    game.taxi.position = center + Vector2(-190, 110)
    game.taxi.landed_on = -1
    game.camera.zoom = Vector2(1.5, 1.5)
    var sheet: Image = Image.create(1040, 1040, false, Image.FORMAT_RGB8)
    var samples: Array[float] = [0.15, 0.55, 0.95, 1.35]
    var first: PackedByteArray
    for index in range(samples.size()):
        game.sector.elapsed = samples[index]
        game.sector.queue_redraw()
        game._process(0.01)
        game.camera.position = center
        game.camera.reset_smoothing()
        await process_frame
        await RenderingServer.frame_post_draw
        var frame: Image = root.get_texture().get_image().get_region(Rect2i(380, 100, 520, 520))
        frame.convert(Image.FORMAT_RGB8)
        if index == 0:
            first = frame.get_data()
        elif index == 3:
            assert(first != frame.get_data(), "The rendered black-hole animation must visibly change")
        sheet.blit_rect(frame, Rect2i(0, 0, 520, 520), Vector2i((index % 2) * 520, (index / 2) * 520))
    sheet.save_png("res://tests/black-hole-animation.png")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    quit()
