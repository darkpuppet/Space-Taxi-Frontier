extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_preview_unused.cfg"
    root.add_child(game)
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/briefing.png")
    game._resume()
    game.taxi.set_physics_process(false)
    game._process(1.1)
    for i in range(30):
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/flight.png")
    game.level = 19
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game.sector._physics_process(6.0)
    game.taxi.position = Vector2(1350, 1080)
    game.taxi.engine_on = true
    game.passenger_onboard = true
    game._refresh_ui()
    game._process(0.1)
    game.camera.reset_smoothing()
    for i in range(5):
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/sector20.png")
    game.camera.zoom = Vector2(0.5, 0.5)
    var sheet: Image = Image.create(1600, 1125, false, Image.FORMAT_RGB8)
    for level in range(20):
        game.level = level
        game._start_level()
        game.taxi.set_physics_process(false)
        game.sector.set_physics_process(false)
        game.sector._physics_process(1.7)
        game.taxi.position = Vector2(1200, 720)
        game.passenger_onboard = true
        game._refresh_ui()
        game._process(0.1)
        game.camera.reset_smoothing()
        for i in range(3):
            await process_frame
        await RenderingServer.frame_post_draw
        var frame: Image = root.get_texture().get_image()
        frame.convert(Image.FORMAT_RGB8)
        frame.resize(400, 225, Image.INTERPOLATE_LANCZOS)
        sheet.blit_rect(frame, Rect2i(0, 0, 400, 225), Vector2i((level % 4) * 400, int(level / 4) * 225))
    sheet.save_png("res://tests/campaign-preview.png")
    game.camera.zoom = Vector2.ONE
    game._new_game()
    game.level = 2
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game.taxi.landed_on = -1
    game.taxi.position = Vector2(1280, 650)
    game.dispatcher.waiting[0]["patience"] = 9.0
    game._announce("Two waiting fares / Pick them up before their patience runs out.")
    game._process(0.01)
    game.camera.reset_smoothing()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/passengers.png")
    for index in range(3):
        game.taxi.landed_on = game.source_pad
        game._on_landed(game.source_pad)
        game._process(1.1)
        var destination: int = game.destination_pad
        game.taxi.landed_on = destination
        game.taxi.position = Vector2(game.pads[destination - 1]["x"], game.pads[destination - 1]["y"] - 21)
        game._on_landed(destination)
        game._process(0.01)
    game.taxi.position = game.gate_position + Vector2(-125, 45)
    game.taxi.landed_on = -1
    game.taxi.engine_on = true
    game._process(0.01)
    game.camera.reset_smoothing()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/star-gate.png")
    game._new_game()
    game.level = 8
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var center: Vector2 = game.sector.holes[0]["position"]
    game.taxi.position = center + Vector2(34, 0)
    game.taxi._begin_capture(center)
    var comedy: Image = Image.create(1280, 720, false, Image.FORMAT_RGB8)
    for frame_id in range(4):
        game.taxi._animate_capture(0.2 if frame_id == 0 else 0.3)
        game._process(0.01)
        game.camera.reset_smoothing()
        await process_frame
        await RenderingServer.frame_post_draw
        var frame: Image = root.get_texture().get_image()
        frame.convert(Image.FORMAT_RGB8)
        frame.resize(640, 360, Image.INTERPOLATE_LANCZOS)
        comedy.blit_rect(frame, Rect2i(0, 0, 640, 360), Vector2i((frame_id % 2) * 640, int(frame_id / 2) * 360))
    comedy.save_png("res://tests/black-hole-preview.png")
    game.taxi._animate_capture(0.3)
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/life-lost.png")
    game._resume()
    game.taxi.set_physics_process(false)
    game._show_pause()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/pause.png")
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.15).timeout
    quit()
