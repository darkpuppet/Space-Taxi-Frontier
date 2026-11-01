extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_damage_preview.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game.taxi.position = Vector2(1200, 650)
    game.taxi.landed_on = 1
    game.camera.zoom = Vector2(3, 3)
    var caption := Label.new()
    caption.position = Vector2(430, 475)
    caption.add_theme_font_size_override("font_size", 24)
    caption.add_theme_color_override("font_shadow_color", Color.BLACK)
    caption.add_theme_constant_override("shadow_outline_size", 4)
    game.hud.add_child(caption)
    var sheet: Image = Image.create(1680, 840, false, Image.FORMAT_RGB8)
    var hulls: Array[float] = [100, 70, 50, 25, 10, 100]
    var titles: Array[String] = ["PRISTINE / 100%", "SCUFFED / 70%", "SMOKING / 50%", "HEAVY DAMAGE / 25%", "CRITICAL / 10%", "REPAIRED / 100%"]
    for index in range(hulls.size()):
        if index == 5:
            game.taxi.repair(100)
        else:
            game.taxi.hull = hulls[index]
            game.taxi.damage_smoke.clear()
            game.taxi.smoke_clock = 0
        for step in range(30):
            game.taxi._physics_process(0.05)
        game._process(0.01)
        game.camera.reset_smoothing()
        caption.text = titles[index]
        await process_frame
        await RenderingServer.frame_post_draw
        var frame: Image = root.get_texture().get_image().get_region(Rect2i(360, 100, 560, 420))
        frame.convert(Image.FORMAT_RGB8)
        sheet.blit_rect(frame, Rect2i(0, 0, 560, 420), Vector2i((index % 3) * 560, (index / 3) * 420))
    sheet.save_png("res://tests/damage-preview.png")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    quit()
