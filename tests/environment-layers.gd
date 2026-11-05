extends SceneTree
var failures: int = 0
var checks: int = 0
const PROFILE: String = "user://frontier_environment_layers_test"

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func settle(game: Node) -> void:
    await process_frame
    await process_frame
    game.environment_layers._process(0)

func capture(name: String) -> void:
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        DirAccess.make_dir_recursive_absolute("res://.development")
        root.get_texture().get_image().save_png("res://.development/" + name + ".png")

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = PROFILE + ".cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game._process(0)
    game.camera.position_smoothing_enabled = false
    var layers: Node = game.environment_layers
    check(layers.get_child_count() == 5, "Environment has exactly five scenic planes")
    check(layers.static_sky.z_index < layers.planet_scenery.z_index and layers.planet_scenery.z_index < layers.window_glass.z_index and layers.window_glass.z_index < layers.window_frame.z_index and layers.window_frame.z_index < layers.buildings.z_index, "Stars, planets, glass, frame and buildings draw in requested order")
    check(layers.animated_elements.get_parent() == layers.static_sky, "Animated starfield activity stays in the bottommost layer")
    check(game.aurora_background.get_parent() == layers.animated_elements, "Aurora belongs to animated background plane")
    game.camera.position = Vector2(850, 650)
    await settle(game)
    var sky_screen: Vector2 = layers.static_sky.get_global_transform_with_canvas().origin
    var old_animated: Vector2 = layers.animated_elements.global_position
    var old_planets: Vector2 = layers.planet_scenery.position
    var old_frame: Vector2 = layers.window_frame.position
    var old_buildings: Vector2 = layers.buildings.position
    var old_center: Vector2 = game.camera.get_screen_center_position()
    var ship_position: Vector2 = game.taxi.position
    var hazards: Array = game.sector.navigation_markers().duplicate(true)
    await capture("layers-level-01-before")
    game.camera.position += Vector2(300, 160)
    await settle(game)
    var travel: Vector2 = game.camera.get_screen_center_position() - old_center
    check(layers.static_sky.get_global_transform_with_canvas().origin.is_equal_approx(sky_screen), "Starscape remains fixed on screen as camera moves")
    check((layers.animated_elements.global_position - old_animated).is_equal_approx(travel * (Vector2.ONE - layers.animated_scroll_scale)), "Animated starfield activity retains independent subtle parallax")
    check((layers.planet_scenery.position - old_planets).is_equal_approx(travel * (Vector2.ONE - layers.planet_scroll_scale)), "Celestial plane has its own parallax rate")
    check((layers.window_frame.position - old_frame).is_equal_approx(travel * (Vector2.ONE - layers.window_scroll_scale)), "Window frame has its own parallax rate")
    check(layers.window_frame.position.is_equal_approx(layers.window_glass.position), "Glass stays registered with its frame")
    check(layers.buildings.position.is_equal_approx(old_buildings), "Nearest buildings track world movement")
    check(game.taxi.position == ship_position and game.sector.navigation_markers() == hazards, "Parallax does not move taxi or gameplay hazards")
    await capture("layers-level-01-after")
    game.camera.position = Vector2(900, 1200)
    await settle(game)
    await capture("layers-level-01-buildings")
    layers.parallax_enabled = false
    layers._process(0)
    check(layers.animated_elements.global_position == Vector2.ZERO and layers.planet_scenery.position == Vector2(-96, -96), "Disabling parallax restores authored world registration")
    layers.parallax_enabled = true
    for index in range(20):
        game.level = index
        game._start_level()
        game._resume()
        game.taxi.set_physics_process(false)
        game.sector.set_physics_process(false)
        game._process(0)
        layers = game.environment_layers
        check(layers.get_parent() == game.sector and layers.get_child_count() == 5, "Each sector scene owns exactly five layers without stacking")
        check(layers.planet_scenery.texture != null and layers.buildings.texture != null, "Every sector supplies its source artwork")
        if index in [2, 5, 17]:
            game.camera.position = Vector2(850, 650)
            await settle(game)
            await capture("layers-level-%02d" % (index + 1))
    var clock: float = game.background_traffic.clock
    game._show_pause()
    game._process(10)
    check(game.background_traffic.clock == clock, "Pause freezes animated background activity")
    game._return_to_menu()
    layers = game.environment_layers
    check(not layers.visible, "Title menu hides all environment planes")
    game._new_game()
    check(layers.visible, "Starting a shift restores the layered environment")
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    await create_timer(0.2).timeout
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix):
            DirAccess.remove_absolute(PROFILE + suffix)
    print("Environment layers: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
