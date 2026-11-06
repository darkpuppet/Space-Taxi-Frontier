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
    var roof: Vector2 = CRUMPLE.point(Vector2(0.5, 0.0), 1.0 / 6.0)
    check(roof.y > CRUMPLE.point(Vector2(0.5, 0.0), 0.0).y + 8.0, "First crush caves the cabin roof inward")
    check(CRUMPLE.point(Vector2(1.0, 0.5), 2.0 / 6.0).x < CRUMPLE.point(Vector2(1.0, 0.5), 1.0 / 6.0).x - 12.0, "Second crush folds the nose toward the cabin")
    check(is_equal_approx(CRUMPLE.point(Vector2(0.0, 0.5), 2.0 / 6.0).x, -37.0), "Front impact leaves the rear for its own crushing stage")
    check(CRUMPLE.point(Vector2(0.0, 0.5), 3.0 / 6.0).x > -25.0, "Third crush collapses the engine housing from the rear")
    check(CRUMPLE.point(Vector2(0.5, 1.0), 4.0 / 6.0).y < CRUMPLE.point(Vector2(0.5, 1.0), 3.0 / 6.0).y - 5.0, "Fourth crush buckles the undercarriage upward")
    # A crushed shell has a few broad dents, not repeating sawtooth pleats.
    for step in range(1, 7):
        for y in [0.0, 0.5, 1.0]:
            var turns: int = 0
            var previous_slope: float = 0.0
            var previous: Vector2 = CRUMPLE.point(Vector2(0.0, y), float(step) / 6.0)
            for column in range(1, CRUMPLE.COLUMNS + 1):
                var point: Vector2 = CRUMPLE.point(Vector2(float(column) / CRUMPLE.COLUMNS, y), float(step) / 6.0)
                var slope: float = point.y - previous.y
                if absf(slope) > 0.1:
                    if previous_slope * slope < 0.0:
                        turns += 1
                    previous_slope = slope
                previous = point
            check(turns <= 3, "Body panels form localized dents without regular accordion pleats")
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
    var audio_children: int = game.audio.get_child_count()
    ship.rotation = 0.3
    ship.visual_tilt = 0.1
    var center: Vector2 = ship.position + Vector2(70, -25)
    var hole: Dictionary = {"position": center, "home": center, "phase": 0.0, "drift": 60.0, "radius": 18.0}
    game.sector.holes.append(hole)
    var contact: Dictionary = game.sector.contact_at(center)
    ship._begin_capture(contact["center"], contact["hole"])
    check(ship.rotation == 0 and ship.visual_tilt == 0, "Capture immediately straightens the cab without spinning")
    check(ship.position.is_equal_approx(center), "Capture immediately locks the taxi to the singularity center")
    var cab_texture: Texture2D = ship.capture_texture
    var sound: AudioStreamWAV = game.audio.crumple_player.stream
    check(ship.capture_active and cab_texture != null, "Capture snapshots the actual taxi painting for deformation")
    check(game.audio.crumple_player.playing, "Singularity entry starts the dedicated metallic crumple sound")
    check(game.audio.get_child_count() == audio_children, "Capture plays no competing synthesized suction jingle")
    game.audio._process(1.0)
    check(game.audio.music.volume_db <= -34.0 and game.audio.crumple_player.volume_db >= -6.0, "Recorded metal crinkling stays audible above the music during capture")
    check(is_equal_approx(sound.get_length(), CRUMPLE.DURATION) and sound.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Crushing audio matches the capture duration without looping")
    check(sound.mix_rate == 48000 and sound.stereo and sound.format == AudioStreamWAV.FORMAT_16_BITS, "Bundled WAV preserves 48 kHz stereo PCM detail")
    var peaks: int = 0
    for index in range(CRUMPLE.BUCKLE_TIMES.size()):
        var buckle: float = CRUMPLE.BUCKLE_TIMES[index]
        var peak: int = 0
        for sample in range(int((buckle + 0.003) * sound.mix_rate), int((buckle + 0.035) * sound.mix_rate)):
            peak = maxi(peak, absi(sound.data.decode_s16(sample * 4)))
        peaks += int(peak > 5000)
        var before: float = CRUMPLE.progress_at(buckle)
        var after: float = CRUMPLE.progress_at(buckle + CRUMPLE.BUCKLE_DURATION)
        check(after - before > 0.16, "Each audible crunch advances one visible buckle")
        var next_buckle: float = CRUMPLE.BUCKLE_TIMES[index + 1] if index + 1 < CRUMPLE.BUCKLE_TIMES.size() else CRUMPLE.SWALLOW_TIME
        check(is_equal_approx(after, CRUMPLE.progress_at(next_buckle - 0.01)), "Each crumple stage holds before the next crunch")
    check(peaks == 6, "Recorded metal collapses remain audible during all six visual buckles")
    var continuous_windows: int = 0
    for window in range(3, 17):
        var energy: float = 0.0
        var count: int = int(sound.mix_rate * 0.05)
        for frame in range(count):
            var at: int = int(float(window) * 0.1 * sound.mix_rate) + frame
            var value: float = sound.data.decode_s16(at * 4)
            energy += value * value
        continuous_windows += int(sqrt(energy / count) > 500.0)
    check(continuous_windows == 14, "Natural metal crinkling continues between major buckles without repeated silent gaps")
    check(CRUMPLE.BUCKLE_TIMES[1] - CRUMPLE.BUCKLE_TIMES[0] > CRUMPLE.BUCKLE_TIMES[3] - CRUMPLE.BUCKLE_TIMES[2] and CRUMPLE.BUCKLE_TIMES[3] - CRUMPLE.BUCKLE_TIMES[2] > CRUMPLE.BUCKLE_TIMES[5] - CRUMPLE.BUCKLE_TIMES[4], "Crushing escalates from slow to fast to fastest while anchored")
    check(CRUMPLE.DURATION < 2.2, "Comedic capture finishes more quickly")
    DirAccess.make_dir_recursive_absolute("res://.development/crumple")
    sound.save_to_wav("res://.development/crumple/tin-can.wav")
    ship._begin_capture(ship.position)
    check(ship.capture_time == 0, "Repeated contact cannot restart an active capture")
    for i in range(8):
        game.sector._physics_process(0.05)
        ship._physics_process(0.05)
        check(ship.position.is_equal_approx(hole["position"]), "Crushing taxi stays locked to the moving singularity center")
    check(ship.crumple_progress > 0.15 and ship.scale.x > 0.99, "Cab folds while still full-sized and readable")
    check(ship.rotation == 0 and ship.visual_tilt == 0 and not ship.capture_center.is_equal_approx(center), "Taxi remains upright while following singularity drift")
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
    for i in range(25):
        ship._physics_process(0.05)
    ship._physics_process(0.025)
    check(ship.capture_active and ship.scale == Vector2.ONE and ship.modulate.a == 1.0 and ship.crumple_progress > 0.99, "Fully crushed wreck remains full-sized and opaque before swallowing")
    for i in range(8):
        ship._physics_process(0.05)
    check(ship.scale.x < 0.02 and ship.modulate.a == 1.0 and ship.rotation == 0 and ship.visual_tilt == 0, "Cab stays upright and opaque until the last tiny sliver crunches to zero")
    ship._physics_process(0.05)
    check(ship.capture_active and game.lives == 3 and ship.position.is_equal_approx(ship.capture_center) and ship.scale == Vector2.ONE, "A small flash plays at the disappearance point before the life-loss overlay")
    game.sector._physics_process(0.01)
    ship._physics_process(0.01)
    check(ship.position.is_equal_approx(hole["position"]), "Final spark follows the same moving singularity center")
    held = ship.capture_time
    game._show_pause()
    ship.set_physics_process(true)
    await physics_frame
    await physics_frame
    check(ship.capture_time == held, "Pausing freezes the disappearance glint")
    game._resume()
    ship.set_physics_process(false)
    for i in range(4):
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
    game.audio._process(1.0)
    check(is_equal_approx(game.audio.music.volume_db, -27.0), "Leaving capture restores normal menu music volume")
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
                check(bounds.size.x < intact.size.x * 0.55 and bounds.size.y > intact.size.y * 0.5, "GPU-rendered cab becomes a compact irregular wreck while retaining its crushed body painting")
            sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, view.size), Vector2i(index * 240, 0))
        sheet.save_png("res://.development/crumple/stages.png")
        visual.capture_time = CRUMPLE.DURATION
        visual.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        var pop: Image = view.get_texture().get_image()
        var core: Color = pop.get_pixel(120, 80)
        check(core.r > 0.9 and core.g > 0.9 and core.a > 0.5 and ink_bounds(pop).size.x < 100, "GPU-rendered disappearance pop has a small bright core")
        pop.save_png("res://.development/crumple/disappearance-pop.png")
        visual.capture_time = CRUMPLE.DURATION + CRUMPLE.POP_DURATION + 0.01
        visual.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        check(not ink_bounds(view.get_texture().get_image()).has_area(), "The glint fades completely and leaves no taxi painting behind")
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
