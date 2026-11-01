extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_accident_preview.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    for child in game.hud.get_children():
        if child is CanvasItem:
            child.hide()
    var caption := Label.new()
    caption.position = Vector2(440, 620)
    caption.add_theme_font_size_override("font_size", 22)
    caption.add_theme_color_override("font_shadow_color", Color.BLACK)
    caption.add_theme_constant_override("shadow_outline_size", 4)
    game.hud.add_child(caption)
    game.camera.zoom = Vector2(2.5, 2.5)
    var sheet: Image = Image.create(1120, 680, false, Image.FORMAT_RGB8)
    for species in range(2):
        game.level = species
        game._start_level()
        game.taxi.set_physics_process(false)
        game.sector.set_physics_process(false)
        var rider: Dictionary = game.dispatcher.waiting[0]
        var pad: Dictionary = game.pads[int(rider["source"]) - 1]
        var point := Vector2(game._fare_home_x(pad), float(pad["y"]) - 2)
        game.taxi.position = point + Vector2(0, -19)
        game.taxi.landed_on = int(rider["source"])
        game._on_taxi_flight_motion(point - Vector2(0, 140), point - Vector2(0, 19))
        for stage in range(2):
            if stage == 1:
                game.taxi.position.x = float(pad["x"]) - 40
            game._process(0.08 if stage == 0 else 1.2)
            game.camera.position = Vector2(pad["x"], float(pad["y"]) - 80)
            game.camera.reset_smoothing()
            caption.text = ("GREEN ALIEN / " if species == 1 else "RED HUMAN / ") + ("IMPACT" if stage == 0 else "MEMORIAL")
            await process_frame
            await RenderingServer.frame_post_draw
            var frame: Image = root.get_texture().get_image().get_region(Rect2i(400, 320, 560, 340))
            frame.convert(Image.FORMAT_RGB8)
            sheet.blit_rect(frame, Rect2i(0, 0, 560, 340), Vector2i(stage * 560, species * 340))
    sheet.save_png("res://tests/passenger-accidents.png")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    quit()
