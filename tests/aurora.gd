extends SceneTree
var checks: int = 0
var failures: int = 0
const PROFILE: String = "user://frontier_aurora_test"

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func capture() -> Image:
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(1280, 720)
    var backdrop: Sprite2D = load("res://scripts/aurora_background.gd").new()
    root.add_child(backdrop)
    backdrop.configure(2, Vector2(1280, 720), 0.0)
    var first: Image = await capture()
    backdrop.advance(4.0)
    var second: Image = await capture()
    var changed: int = 0
    var ground_changed: int = 0
    var planet_changed: int = 0
    for y in range(720):
        for x in range(1280):
            if first.get_pixel(x, y) != second.get_pixel(x, y):
                changed += 1
                if y >= 570:
                    ground_changed += 1
                if x >= 1100 and y < 250:
                    planet_changed += 1
    check(changed > 2000, "Painted aurora curtains visibly ripple and shimmer")
    check(ground_changed == 0, "Ice mountains and ground remain stationary")
    check(planet_changed == 0, "Distant planets and their sky remain stationary")
    var held: Image = await capture()
    check(held.get_data() == second.get_data(), "Aurora cannot advance without explicit game time")
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--preview-dir="):
            var preview_dir: String = argument.trim_prefix("--preview-dir=")
            check(first.save_png(preview_dir.path_join("aurora-before.png")) == OK, "Save initial aurora preview")
            check(second.save_png(preview_dir.path_join("aurora-after.png")) == OK, "Save animated aurora preview")
    # Exercise the actual repainted sky used by level 3, not just legacy art.
    backdrop.configure(2, Vector2(1280, 720), 4.0, load("res://assets/backgrounds/layers/level-03/sky-v1.png"))
    backdrop.material.set_shader_parameter("repainted_sky", true)
    var waving: Image = await capture()
    backdrop.material.set_shader_parameter("wave_strength", 0.0)
    var still_curtains: Image = await capture()
    backdrop.advance(12.0)
    var recolored: Image = await capture()
    var moved_pixels: int = 0
    var hue_pixels: int = 0
    var clear_sky_changes: int = 0
    for y in range(720):
        for x in range(1280):
            if waving.get_pixel(x, y) != still_curtains.get_pixel(x, y):
                moved_pixels += 1
            var before: Color = still_curtains.get_pixel(x, y)
            var after: Color = recolored.get_pixel(x, y)
            if absf(before.h - after.h) > 0.06 and before.v > 0.15 and after.v > 0.15:
                hue_pixels += 1
            if x > 1000 and y < 180 and before != after:
                clear_sky_changes += 1
    check(moved_pixels > 2000, "Level 3's current sky has visible waving independent of color cycling")
    check(hue_pixels > 2000, "Aurora changes hue rather than only pulsing brightness")
    check(clear_sky_changes == 0, "Sky outside the aurora remains stationary and keeps its colors")
    backdrop.material.set_shader_parameter("wave_strength", 1.0)
    var waving_later: Image = await capture()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--preview-dir="):
            var preview_dir: String = argument.trim_prefix("--preview-dir=")
            waving.save_png(preview_dir.path_join("aurora-level-03-before.png"))
            waving_later.save_png(preview_dir.path_join("aurora-level-03-after.png"))
    backdrop.free()
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = PROFILE + ".cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.level = 2
    game._start_level()
    game._resume()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(game.aurora_background.visible, "Ice Moon enables the animated background")
    game._process(0.5)
    var before_pause: float = game.aurora_background.material.get_shader_parameter("aurora_time")
    check(is_equal_approx(before_pause, game.pulse), "Aurora follows the gameplay clock")
    game._show_pause()
    game._process(10.0)
    check(is_equal_approx(game.aurora_background.material.get_shader_parameter("aurora_time"), before_pause), "Pause freezes aurora animation")
    game._resume()
    game._process(0.5)
    check(game.aurora_background.visible and game.aurora_background.material.get_shader_parameter("aurora_time") > before_pause, "Resuming restores and advances the aurora")
    var existing: Sprite2D = game.aurora_background
    game._start_level()
    check(game.aurora_background == existing, "Retry reuses the backdrop without stacking shader layers")
    game.level = 3
    game._start_level()
    check(not game.aurora_background.visible, "Other sectors retain their original backgrounds")
    game.level = 2
    game._start_level()
    game._resume()
    check(game.aurora_background.visible, "Revisiting Ice Moon restores its aurora")
    game._return_to_menu()
    check(not game.aurora_background.visible, "The title menu hides the world aurora")
    game._new_game()
    check(not game.aurora_background.visible, "Starting a new campaign clears the Ice Moon backdrop")
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    # Allow the audio/render servers to release the game's queued resources.
    await create_timer(0.2).timeout
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix):
            DirAccess.remove_absolute(PROFILE + suffix)
    print("Ice Moon aurora: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
