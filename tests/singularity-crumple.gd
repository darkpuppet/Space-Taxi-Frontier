extends SceneTree
const CRUMPLE = preload("res://scripts/cab_crumple.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func ink_bounds(pixels: Image) -> Rect2i:
    var bounds := Rect2i()
    var found: bool = false
    for y in range(pixels.get_height()):
        for x in range(pixels.get_width()):
            if pixels.get_pixel(x, y).a < 0.2:
                continue
            if not found:
                bounds = Rect2i(x, y, 1, 1)
                found = true
            else:
                bounds = bounds.merge(Rect2i(x, y, 1, 1))
    return bounds

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_crumple_test.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game._resume()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var ship: Node = game.taxi
    ship._begin_capture(ship.position + Vector2(70, -25))
    var cab_texture: Texture2D = ship.capture_texture
    var sound: AudioStreamWAV = game.audio.crumple_player.stream
    check(ship.capture_active and cab_texture != null, "Capture snapshots the actual taxi painting for deformation")
    check(game.audio.crumple_player.playing, "Singularity entry starts the dedicated metallic crumple sound")
    check(is_equal_approx(sound.get_length(), CRUMPLE.DURATION) and sound.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Crushing audio matches the capture duration without looping")
    check(sound.mix_rate == 48000 and sound.stereo and sound.format == AudioStreamWAV.FORMAT_16_BITS, "Bundled WAV preserves 48 kHz stereo PCM detail")
    var peaks: int = 0
    for buckle in CRUMPLE.BUCKLE_TIMES:
        var peak: int = 0
        for sample in range(int((buckle + 0.003) * sound.mix_rate), int((buckle + 0.035) * sound.mix_rate)):
            peak = maxi(peak, absi(sound.data.decode_s16(sample * 4)))
        peaks += int(peak > 5000)
        var before: float = CRUMPLE.progress_at(buckle)
        var after: float = CRUMPLE.progress_at(buckle + CRUMPLE.BUCKLE_DURATION)
        check(after - before > 0.16, "Each audible crunch advances one visible buckle")
        check(is_equal_approx(after, CRUMPLE.progress_at(buckle + 0.25)), "Each crumple stage holds before the next crunch")
    check(peaks == 6, "Six substantial metallic buckles are encoded in the audio")
    DirAccess.make_dir_recursive_absolute("res://.development/crumple")
    sound.save_to_wav("res://.development/crumple/tin-can.wav")
    ship._begin_capture(ship.position)
    check(ship.capture_time == 0, "Repeated contact cannot restart an active capture")
    for i in range(8):
        ship._physics_process(0.05)
    check(ship.crumple_progress > 0.15 and ship.scale.x > 0.99, "Cab folds while still full-sized and readable")
    var held: float = ship.capture_time
    game._show_pause()
    ship.set_physics_process(true)
    game.audio._process(0)
    await physics_frame
    await physics_frame
    check(ship.capture_time == held and game.audio.crumple_player.stream_paused, "Pause freezes both crushing motion and crushing sound")
    game._resume()
    ship.set_physics_process(false)
    game.audio._process(0)
    check(not game.audio.crumple_player.stream_paused, "Resuming releases the crushing sound")
    game.audio.toggle_mute()
    game.audio._process(0)
    check(not game.audio.crumple_player.stream_paused, "Mute preserves the sound timeline so unmuting stays synchronized")
    game.audio.toggle_mute()
    for i in range(32):
        ship._physics_process(0.05)
    check(ship.capture_active and ship.scale == Vector2.ONE and ship.modulate.a == 1.0 and ship.crumple_progress > 0.99, "Fully crushed wreck remains full-sized and opaque before swallowing")
    for i in range(15):
        ship._physics_process(0.05)
    check(game.lives == 2 and game.screen_state == "life_lost", "Finished crumpling consumes exactly one life")
    check(not game.audio.crumple_player.playing, "Losing the taxi stops the crushing sound")
    ship._physics_process(0.05)
    check(game.lives == 2, "A crushed cab cannot consume another life")
    game._resume()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(game.taxi.crumple_progress == 0 and game.taxi.capture_texture == null and game.taxi.scale == Vector2.ONE, "Retry restores an uncrumpled taxi")
    game.taxi._begin_capture(game.taxi.position + Vector2(50, 0))
    game._return_to_menu()
    check(not game.audio.crumple_player.playing, "Returning to the menu immediately cancels crushing audio")
    game._new_game()
    game._resume()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game.taxi._begin_capture(game.taxi.position + Vector2(50, 0))
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(not game.audio.crumple_player.playing and game.taxi.crumple_progress == 0, "Restarting mid-capture clears both crumple sound and cab deformation")
    if DisplayServer.get_name() != "headless":
        var view := SubViewport.new()
        view.size = Vector2i(240, 160)
        view.transparent_bg = true
        view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(view)
        var visual: Node2D = load("res://Taxi.tscn").instantiate()
        view.add_child(visual)
        visual.set_physics_process(false)
        visual.position = Vector2(120, 80)
        visual.scale = Vector2.ONE * 2.5
        visual.capture_texture = cab_texture
        visual.capture_active = true
        var sheet := Image.create(1680, 160, false, Image.FORMAT_RGBA8)
        var intact: Rect2i
        var previous_frame := PackedByteArray()
        for index in range(7):
            visual.crumple_progress = float(index) / 6
            visual.queue_redraw()
            await process_frame
            await RenderingServer.frame_post_draw
            var frame := view.get_texture().get_image()
            var bounds := ink_bounds(frame)
            if index == 0:
                intact = bounds
            else:
                check(frame.get_data() != previous_frame, "Every rendered buckle visibly changes the taxi painting")
            previous_frame = frame.get_data()
            if index == 6:
                check(bounds.size.x < intact.size.x * 0.55 and bounds.size.y > intact.size.y * 0.5, "GPU-rendered cab becomes a folded metal lump rather than a uniformly scaled sprite")
            sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, view.size), Vector2i(index * 240, 0))
        sheet.save_png("res://.development/crumple/stages.png")
        view.free()
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    await create_timer(0.2).timeout
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        var path: String = "user://frontier_crumple_test" + suffix
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
    print("Singularity tin-can crumple: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
