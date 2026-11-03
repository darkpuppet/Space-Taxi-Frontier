extends SceneTree
var failures: int = 0
var checks: int = 0
const PROFILE: String = "user://frontier_background_traffic_test"

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func _run() -> void:
    var placements = preload("res://scripts/background_traffic.gd").new()
    var world_size := Vector2(2400, 1440)
    for level in range(20):
        for sample in range(12):
            placements.configure(level)
            check(placements.stars.size() == placements.STAR_COUNT, "Every sector retains its full star field")
            for star in placements.stars:
                var size := Vector2.ONE * float(star["size"])
                var footprint := Rect2(Vector2(star["position"]) - size * 0.5, size)
                check(placements.sky_region.encloses(footprint.grow(7.0)), "Every twinkle stays fully within the reviewed open sky, including its glow")
        check(not placements.sky_region.has_point(Vector2(0.5, 0.9) * world_size), "Stars never reach the lower painted landscape")
    # Specific silhouettes that the previous full-height scatter could overlap.
    for landmark in [[0, Vector2(0.50, 0.65)], [2, Vector2(0.05, 0.40)], [4, Vector2(0.29, 0.32)], [8, Vector2(0.83, 0.25)], [11, Vector2(0.10, 0.15)], [12, Vector2(0.41, 0.28)], [14, Vector2(0.18, 0.35)], [17, Vector2(0.34, 0.47)]]:
        placements.configure(int(landmark[0]))
        check(not placements.sky_region.has_point(Vector2(landmark[1]) * world_size), "Painted planets, spires, moons, asteroids, gardens and station walls stay outside the star field")
    placements.rng.seed = 73119
    var headings: Dictionary = {}
    var view := Rect2(Vector2.ZERO, world_size)
    for kind in [1, 2]:
        for sample in range(80):
            placements.passers.clear()
            placements._spawn(kind)
            var passer: Dictionary = placements.passers[0]
            var velocity: Vector2 = passer["velocity"]
            var pitch: float = absf(rad_to_deg(atan2(velocity.y, absf(velocity.x))))
            check(pitch >= 11.99 and pitch <= 35.01, "Comets and ships take clearly diagonal paths")
            check(velocity.length() >= (100.0 if kind == 1 else 45.0) and velocity.length() <= (145.0 if kind == 1 else 70.0), "Diagonal flight preserves the visitor's intended speed")
            var facing: Transform2D = placements.passer_transform(passer)
            check(facing.x.normalized().dot(velocity.normalized()) > 0.9999, "The comet head and ship bow lead the direction of travel, with the tail behind")
            check(facing.y.y > 0.0, "Leftward and rightward ships stay upright")
            check(not view.has_point(Vector2(passer["position"])), "Diagonal visitors enter from offscreen")
            var crosses_view: bool = false
            for step in range(151):
                if view.grow(-80.0).has_point(Vector2(passer["position"]) + velocity * float(step) * 0.5):
                    crosses_view = true
                    break
            check(crosses_view, "Every diagonal path crosses the visible world before expiry")
            headings[Vector2i(signi(int(velocity.x)), signi(int(velocity.y)))] = true
    check(headings.size() == 4, "Visitors travel upward and downward in both horizontal directions")
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = PROFILE + ".cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var traffic: RefCounted = game.background_traffic
    check(traffic.ATLAS.resource_path.ends_with(".png"), "Background animation loads the replacement PNG atlas")
    var atlas_image: Image = traffic.ATLAS.get_image()
    check(atlas_image.detect_alpha() != Image.ALPHA_NONE, "Background sprites retain transparent backgrounds")
    var cell := Vector2i(atlas_image.get_width() / 4, atlas_image.get_height() / 4)
    for row in range(4):
        for column in range(4):
            var frame: Image = atlas_image.get_region(Rect2i(Vector2i(column, row) * cell, cell))
            check(frame.get_used_rect().has_area(), "Every star, comet, ship, and debris animation frame contains artwork")
    traffic.rng.seed = 73119
    check(traffic.stars.size() == 72 and traffic.passers.is_empty(), "Each level starts with 72 sprite stars and no stale traffic")
    var first: float = traffic.countdown
    check(first >= 4 and first <= 8, "First background visitor arrives shortly after level start")
    traffic.advance(first)
    check(traffic.passers.size() == 1 and int(traffic.passers[0]["kind"]) == 1, "First scheduled visitor is a comet in level one")
    check(traffic.countdown >= 10 and traffic.countdown <= 18, "Subsequent visits are spaced 10-18 seconds apart")
    var start: Vector2 = traffic.passers[0]["position"]
    traffic.advance(0.5)
    check(Vector2(traffic.passers[0]["position"]).distance_to(start) > 40, "Comets visibly move through the background")
    var seen: Dictionary = {}
    for step in range(1200):
        traffic.advance(0.25)
        check(traffic.passers.size() <= 3, "Background activity remains capped at three simultaneous sprites")
        for passer in traffic.passers:
            seen[int(passer["kind"])] = true
    check(seen.size() == 3, "Periodic visits include comets, spaceships and debris")
    var comet_image: Image = traffic.COMET_ATLAS.get_image()
    check(comet_image.detect_alpha() != Image.ALPHA_NONE, "New comet animations preserve alpha transparency")
    var comet_cell := Vector2i(comet_image.get_width() / 4, comet_image.get_height() / 3)
    for row in range(3):
        var first_frame: Image = comet_image.get_region(Rect2i(Vector2i(0, row) * comet_cell, comet_cell))
        for column in range(4):
            var frame: Image = comet_image.get_region(Rect2i(Vector2i(column, row) * comet_cell, comet_cell))
            check(frame.get_used_rect().has_area(), "Every new comet frame contains artwork")
            if column > 0:
                check(frame.get_data() != first_frame.get_data(), "New comet tails animate between frames")
    var comet_types: Dictionary = {}
    for index in range(40):
        traffic.passers.clear()
        var previous_variant: int = traffic.last_comet_variant
        traffic._spawn(1)
        var variant: int = int(traffic.passers[0]["comet_variant"])
        check(variant >= 0 and variant < 4 and variant != previous_variant, "Comet spawns choose a valid type without immediate repeats")
        comet_types[variant] = true
    check(comet_types.size() == 4, "Background traffic includes blue ice, amber ember, green crystal, and violet fork-tail comets")
    traffic.passers.clear()
    for kind in range(1, 4):
        traffic._spawn(kind)
        traffic.passers[-1]["position"] = Vector2(940 + kind * 130, 620 + kind * 80)
        traffic.passers[-1]["velocity"] = Vector2(50, 0)
    traffic.countdown = 15
    game.taxi.position = Vector2(1200, 780)
    game.taxi.landed_on = -1
    var position_before: Vector2 = game.taxi.position
    var hull_before: float = game.taxi.hull
    var radar_markers: int = game.sector.navigation_markers().size()
    game._process(0.2)
    check(traffic.clock > 0 and traffic.passers.size() == 3, "Game advances decorative sprites during play")
    check(game.taxi.position == position_before and game.taxi.hull == hull_before and game.sector.navigation_markers().size() == radar_markers, "Scenery adds no collisions, damage, forces or navigation markers")
    game._show_pause()
    var paused_clock: float = traffic.clock
    var paused_position: Vector2 = traffic.passers[0]["position"]
    var paused_countdown: float = traffic.countdown
    game._process(10)
    check(traffic.clock == paused_clock and traffic.countdown == paused_countdown and traffic.passers[0]["position"] == paused_position, "Pause freezes twinkling, flight and spawn timers")
    game._resume()
    if DisplayServer.get_name() != "headless":
        game.camera.position_smoothing_enabled = false
        game.camera.position = game.taxi.position
        var images: Array[Image] = []
        for time in [0.0, 0.3]:
            traffic.clock = time
            for passer in traffic.passers:
                passer["age"] = time
            game.queue_redraw()
            await process_frame
            await RenderingServer.frame_post_draw
            images.append(root.get_texture().get_image())
        var changed: int = 0
        for y in range(170, 590):
            for x in range(400, 900):
                if images[0].get_pixel(x, y) != images[1].get_pixel(x, y):
                    changed += 1
        check(changed > 100, "Sprite animation changes visible pixels without moving the visitor positions")
        for argument in OS.get_cmdline_user_args():
            if argument.begins_with("--preview-dir="):
                check(images[1].save_png(argument.trim_prefix("--preview-dir=").path_join("background-traffic.png")) == OK, "Save background activity preview")
                var saved_passers: Array[Dictionary] = traffic.passers.duplicate(true)
                traffic.passers.clear()
                for variant in range(4):
                    traffic._spawn(1)
                    traffic.passers[-1]["comet_variant"] = variant
                    traffic.passers[-1]["position"] = Vector2(1200, 620 + variant * 90)
                    traffic.passers[-1]["direction"] = 1.0
                    traffic.passers[-1]["scale"] = 1.0
                game.queue_redraw()
                await process_frame
                await RenderingServer.frame_post_draw
                check(root.get_texture().get_image().save_png(argument.trim_prefix("--preview-dir=").path_join("comet-types.png")) == OK, "Save all four comet types in the game environment")
                traffic.passers.assign(saved_passers)
    traffic.passers[0]["position"] = Vector2(-500, 300)
    traffic.advance(0)
    check(traffic.passers.size() == 2, "Offscreen visitors are removed")
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(traffic.clock == 0 and traffic.passers.is_empty() and traffic.stars.size() == 72, "Retry resets traffic and rebuilds stars")
    game._return_to_menu()
    var menu_clock: float = traffic.clock
    game._process(10)
    check(traffic.clock == menu_clock, "Title menu does not advance level scenery")
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    await create_timer(0.2).timeout
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix):
            DirAccess.remove_absolute(PROFILE + suffix)
    print("Background sprite traffic: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
