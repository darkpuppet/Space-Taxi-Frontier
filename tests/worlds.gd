extends SceneTree
const WORLD = preload("res://scripts/world.gd")
const SPRITES = preload("res://scripts/sprites.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_world_test.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    var positions: Array[Vector2] = []
    var minimum_y: float = INF
    var maximum_y: float = -INF
    for level in range(20):
        game.level = level
        game._start_level()
        game.taxi.set_physics_process(false)
        game.sector.set_physics_process(false)
        check(game.camera.limit_bottom >= WORLD.HEIGHT, "Camera includes the full two-screen world and dashboard clearance")
        var low: float = 0
        var high: float = INF
        for pad in game.pads:
            low = maxf(low, float(pad["y"]))
            high = minf(high, float(pad["y"]))
        check(low - high > 800, "Pads span more than one screen vertically")
        for sample in range(3):
            var pad: Dictionary = game.pads[(level + sample) % 5]
            game.taxi.position = Vector2(pad["x"], pad["y"] - 21)
            game.mission_done = true
            game.gate_rng.seed = 921 + level * 73 + sample * 17
            game._open_star_gate()
            var point: Vector2 = game.gate_position
            positions.append(point)
            minimum_y = minf(minimum_y, point.y)
            maximum_y = maxf(maximum_y, point.y)
            check(point.distance_to(game.taxi.position) >= 500, "Gate requires travel away from the final dropoff")
            check(point.x > 100 and point.x < WORLD.WIDTH - 100 and point.y > 160 and point.y < WORLD.FLOOR - 100, "Gate is inside the playable world")
            check(not game.sector.resolve_motion(point, point, Vector2.ZERO, 60).get("collided", false), "Gate has hull clearance from solid obstacles")
            for platform in game.pads:
                var rectangle := Rect2(float(platform["x"]) - float(platform["width"]) / 2, float(platform["y"]), float(platform["width"]), 25)
                check(not rectangle.grow(60).has_point(point), "Gate is not inside or against a platform")
            var navigation: Dictionary = game._gate_navigation()
            var grid: AStarGrid2D = navigation["grid"]
            var end := Vector2i(roundi((point.x - grid.offset.x) / 64), roundi((point.y - grid.offset.y) / 64))
            check(grid.is_in_boundsv(end) and not grid.is_point_solid(end) and not grid.get_id_path(navigation["start"], end).is_empty(), "Random gate has a traversable route from the taxi")
        print("PASS: Random reachable gates / level %02d" % (level + 1))
        await process_frame
    check(maximum_y - minimum_y > 700, "Random gates vary across the full vertical world")
    check(positions[0] != positions[1] and positions[1] != positions[2], "Repeated plays do not use a fixed gate location")
    game.gate_active = false
    game.taxi.position.y = 450
    game._process(0.01)
    var first_y: float = game.camera.position.y
    game.taxi.position.y = 1150
    game._process(0.01)
    check(game.camera.position.y > first_y + 600, "Camera follows vertical exploration")
    # Verify actual unpowered taxi motion, not just the force formula.
    for family in [game.sector.planets, game.sector.aliens, game.sector.asteroids, game.sector.gates, game.sector.drones, game.sector.mines, game.sector.meteors, game.sector.beams, game.sector.holes]:
        family.clear()
    game.sector.holes.append({"position": Vector2(1000, 650)})
    game.taxi.position = Vector2(820, 650)
    game.taxi.velocity = Vector2.ZERO
    game.taxi.landed_on = -1
    game.taxi.engine_level = 0
    for index in range(30):
        game.taxi._physics_process(1.0 / 60)
    check(game.taxi.position.x > 825 and game.taxi.velocity.x > 20, "Black hole accelerates a coasting taxi inward before contact")
    for point in [Vector2.ZERO, Vector2(WORLD.WIDTH, 0), Vector2(0, WORLD.HEIGHT), Vector2(WORLD.WIDTH, WORLD.HEIGHT)]:
        var pull: Vector2 = game.sector.field_at(point)
        check(pull.is_finite() and pull.length() > 0, "Singularity pulls from every corner of the playfield")
        check(pull.normalized().dot((Vector2(1000, 650) - point).normalized()) > 0.999, "Distant pull points toward the singularity")
    for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
        var previous_strength: float = INF
        for distance in [100.0, 339.0, 340.0, 341.0, 700.0, 1500.0, 2800.0]:
            var strength: float = game.sector.field_at(Vector2(1000, 650) + direction * distance).length()
            check(strength > 0 and strength < previous_strength, "Pull diminishes continuously with distance, including across the former cutoff")
            previous_strength = strength
    game.taxi.position = Vector2(100, 250)
    game.taxi.velocity = Vector2.ZERO
    game.taxi.landed_on = -1
    for index in range(30):
        game.taxi._physics_process(1.0 / 60)
    check(game.taxi.position.x > 100.1 and game.taxi.velocity.x > 1.0, "Singularity actually accelerates a distant coasting taxi beyond the former suction range")
    var dock: Dictionary = game.taxi.pads[0]
    game.taxi.position = Vector2(float(dock["x"]), float(dock["y"]) - 21.0)
    game.taxi.velocity = Vector2.ZERO
    game.taxi.landed_on = int(dock["id"])
    game.sector.holes[0]["position"] = game.taxi.position + Vector2(100, -100)
    var docked_position: Vector2 = game.taxi.position
    for index in range(30):
        game.taxi._physics_process(1.0 / 60)
    check(game.taxi.position.is_equal_approx(docked_position) and game.taxi.velocity == Vector2.ZERO, "Singularity cannot drag a supported taxi off a platform")
    Input.action_press("thrust")
    game.taxi._physics_process(1.0 / 60)
    Input.action_release("thrust")
    check(game.taxi.landed_on == -1 and game.taxi.velocity.x > 1.0, "Suction resumes immediately on takeoff")
    game.sector.holes.clear()
    check(game.sector.field_at(Vector2(100, 250)) == Vector2.ZERO, "Sectors without singularities retain ordinary flight gravity")
    var image: Image = SPRITES.ATLAS.get_image()
    check(image.detect_alpha() != Image.ALPHA_NONE, "Sprite atlas has genuine transparency")
    SPRITES._ensure()
    check(SPRITES.frames.size() == 16, "All 16 ship and passenger poses are loaded")
    for texture in SPRITES.frames:
        check(texture.get_width() > 8 and texture.get_height() > 8, "Sprite region contains visible artwork")
    var bitmaps = preload("res://scripts/bitmap_art.gd")
    var artwork_paths: Dictionary = {}
    for level in range(20):
        var backdrop: Texture2D = bitmaps.background(level)
        check(backdrop != null and backdrop.get_width() >= 1500 and backdrop.get_height() >= 900, "Every sector has a full-resolution bitmap background")
        artwork_paths[backdrop.resource_path] = true
    check(artwork_paths.size() == 20, "All twenty levels use distinct background assets")
    bitmaps.prepare_props()
    check(bitmaps.PROP_ATLAS.get_image().detect_alpha() != Image.ALPHA_NONE, "Platform and service atlas preserves real transparency")
    check(bitmaps.props.size() == 9, "All nine platform and service prop frames load")
    for frame in bitmaps.props:
        check(frame.get_width() > 20 and frame.get_height() > 20, "Prop atlas region contains visible artwork")
        check(Rect2(Vector2.ZERO, bitmaps.PROP_ATLAS.get_size()).encloses(frame.region), "Prop region stays within its source atlas")
    SPRITES.prepare_walk()
    check(SPRITES.walk_frames.size() == 12, "All twelve passenger walking frames load")
    check(SPRITES.WALK_ATLAS.get_image().detect_alpha() != Image.ALPHA_NONE, "Walking sprites retain genuine transparency")
    for frame in SPRITES.walk_frames:
        check(frame.get_width() > 20 and frame.get_height() > 100, "Walking frame contains a complete visible character")
    var game_art = preload("res://scripts/game_art.gd")
    game_art.prepare_hazards()
    game_art.prepare_effects()
    game_art.prepare_damage()
    check(game_art.hazard_frames.size() == 9, "Every remaining hazard, portal and floor category has a sprite")
    check(game_art.effect_frames.size() == 8 and game_art.damage_frames.size() == 8, "Particle textures and all hull/brake variants load")
    for atlas in [game_art.HAZARDS, game_art.EFFECTS, game_art.DAMAGE]:
        check(atlas.get_image().detect_alpha() != Image.ALPHA_NONE, "New sprite atlas preserves transparent backgrounds")
    for frame in game_art.hazard_frames + game_art.damage_frames:
        check(frame.get_width() > 15 and frame.get_height() > 15, "Gameplay sprite region contains visible art")
        check(Rect2(Vector2.ZERO, frame.atlas.get_size()).encloses(frame.region), "Gameplay sprite region stays inside its atlas")
    var portal: Image = game_art.hazard_frames[game_art.Hazard.STAR_GATE].get_image()
    check(portal.get_pixel(portal.get_width() / 2, portal.get_height() / 2).a < 0.05, "Stargate hardware keeps a transparent opening")
    var ring: Image = game_art.effect_frames[game_art.Effect.RING].get_image()
    check(ring.get_pixel(ring.get_width() / 2, ring.get_height() / 2).a < 0.01, "Shockwave particle sprite has a clean transparent center")
    var singularity = preload("res://scripts/black_hole_fx.gd")
    check(singularity.dust_point(7, 0).distance_to(singularity.dust_point(7, 0.3)) > 8, "Black-hole dust visibly travels around the animated disk")
    check(singularity.dust_point(0, 1.8).length() < singularity.dust_point(0, 0.4).length() - 30, "Black-hole dust spirals inward rather than just orbiting")
    for mote in range(singularity.DUST_COUNT):
        for clock in [0.0, 0.3, 2.0, 35.0]:
            var distance: float = singularity.dust_point(mote, clock).length()
            check(distance >= 24 and distance <= 155, "Black-hole visual particles stay in a bounded field")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    print("Tall worlds, random gates, sprites, suction: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
