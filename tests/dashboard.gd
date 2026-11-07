extends SceneTree
var failures: int = 0
var checks: int = 0
const PROFILE: String = "user://frontier_dashboard_test"

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = PROFILE + ".cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game.taxi.fuel = 70
    game.taxi.hull = 65
    game.credits = -300
    game._process(0)
    await process_frame
    await process_frame
    check(game.fuel_readout.text == "FUEL  070 / 140" and game.fuel_bar.value == 70, "Fuel readout follows current tank and capacity")
    check(is_equal_approx(game.fuel_bar.needle_angle(), deg_to_rad(270)), "Half-full tank points needle to midpoint")
    game.fuel_bar.value = 19
    check(game.fuel_bar.warning_lit(), "Low fuel lamp lights immediately below 20 units")
    game.fuel_bar._process(0.55)
    check(game.fuel_bar.low_fuel_active() and not game.fuel_bar.warning_lit(), "Low fuel lamp flashes off during second half of cycle")
    paused = true
    var warning_time: float = game.fuel_bar.warning_clock
    game.fuel_bar._process(1.0)
    check(game.fuel_bar.warning_clock == warning_time, "Pause freezes warning lamp flash")
    paused = false
    game.fuel_bar._process(0.5)
    check(game.fuel_bar.warning_lit(), "Low fuel lamp flashes back on")
    game.fuel_bar.value = 0
    check(game.fuel_bar.low_fuel_active(), "Empty tank keeps warning active")
    game.fuel_bar.value = 20
    check(not game.fuel_bar.low_fuel_active() and game.fuel_bar.warning_clock == 0, "Refueling to 20 clears warning and resets flash")
    check(not game.hull_bar.low_fuel_active(), "Health gauge never shows fuel warning")
    game.fuel_bar.value = 70
    check(game.health_readout.text == "HEALTH  65%" and game.hull_bar.value == 65, "Health gauge shows remaining hull")
    check(game.telemetry.text == "₡%06d" % -300, "Account balance displays debt")
    check(game.fare_readout.text == "₡0000", "Empty taxi has no active fare")
    game.taxi.landed_on = int(game.dispatcher.waiting[0]["source"])
    game._board_passenger()
    game.trip_time = 12
    game._process(0)
    check(game.fare_readout.text == "₡%04d" % game._current_fare(), "Fare meter displays live payout with speed bonus")
    var quoted_fare: int = game._current_fare()
    var balance: int = game.credits
    game._on_landed(game.destination_pad)
    game._process(0)
    check(game.credits == balance + quoted_fare, "Drop-off pays exactly the displayed fare")
    check(game.fare_readout.text == "₡0000", "Fare meter clears after drop-off")
    var original_distance: float = game.distance_meters
    game.taxi.environment = null
    game.taxi.landed_on = -1
    game.taxi.position = Vector2(1100, 400)
    game.taxi.velocity = Vector2(100, 0)
    game.taxi._physics_process(0.05)
    check(game.distance_meters > original_distance + 0.25, "Odometer measures actual flight distance at taxi scale")
    var flight_distance: float = game.distance_meters
    game.taxi.landed_on = 1
    game.taxi.position = Vector2(float(game.pads[0]["x"]), float(game.pads[0]["y"]) - 21)
    game.taxi.velocity = Vector2.ZERO
    game.taxi._physics_process(0.05)
    check(is_equal_approx(game.distance_meters, flight_distance), "Stationary taxi adds no mileage")
    Input.action_press("move_right")
    game.taxi._physics_process(0.05)
    Input.action_release("move_right")
    check(game.distance_meters > flight_distance, "Driving along a platform also counts toward distance")
    game.taxi.input_locked = true
    var driven_distance: float = game.distance_meters
    game.taxi.position += Vector2(300, 100)
    game.taxi._physics_process(0.05)
    check(game.distance_meters == driven_distance, "Tow movement and teleportation do not add mileage")
    game.taxi.input_locked = false
    game._save_game()
    game.distance_meters = 0
    game._load_game()
    check(is_equal_approx(game.distance_meters, driven_distance), "Distance survives a career save and load")
    game._process(0)
    check(is_equal_approx(game.WORLD.meters(74.0), 4.5), "One taxi length equals 4.5 meters")
    check(is_equal_approx(game.WORLD.meters(game.WORLD.WORLD_PIXELS_PER_KILOMETER), 1000.0), "One kilometer matches calibrated ship scale")
    var legacy := ConfigFile.new()
    legacy.load(game.save_file)
    legacy.erase_section_key("career", "distance_scale_version")
    legacy.set_value("career", "distance_meters", 740.0)
    legacy.save(game.save_file)
    game._load_game()
    check(is_equal_approx(game.distance_meters, 45.0), "Old world-pixel odometers migrate to physical meters")
    game._save_game()
    game._load_game()
    check(is_equal_approx(game.distance_meters, 45.0), "Saving migrated distance cannot apply scale twice")
    game.distance_meters = driven_distance
    game.hull_bar.value = 100
    check(is_equal_approx(game.hull_bar.needle_angle(), deg_to_rad(405)), "Full health points needle away from red warning zone")
    game.hull_bar.value = 0
    check(is_equal_approx(game.hull_bar.needle_angle(), deg_to_rad(135)), "Zero health points needle to red warning zone")
    game._process(0)
    game.taxi.position = Vector2(1100, game.FLOOR - 21)
    game._process(0)
    game.camera.reset_smoothing()
    await process_frame
    await process_frame
    var bounds: Rect2 = game.dashboard.get_global_rect()
    check(bounds.position.y >= 570 and bounds.size.y <= 150 and bounds.end.y <= 720 and bounds.end.x <= 1280, "Slim dashboard stays within 150 pixels at bottom of viewport")
    var fare_tab: Rect2 = game.fare_readout.get_parent().get_parent().get_global_rect()
    var balance_tab: Rect2 = game.telemetry.get_parent().get_parent().get_global_rect()
    check(fare_tab.end.y <= game.fuel_bar.get_global_rect().position.y and balance_tab.end.y <= game.hull_bar.get_global_rect().position.y, "Fare and balance tabs sit above the gauges")
    check(is_equal_approx(fare_tab.get_center().x, game.fuel_bar.get_global_rect().get_center().x) and is_equal_approx(balance_tab.get_center().x, game.hull_bar.get_global_rect().get_center().x), "Money tabs align with their gauges")
    check(game.help_button.get_global_rect().end.x <= bounds.end.x, "Help icon fits inside dashboard")
    check(game.radar.visible and not game.controls.visible and not game.mission_panel.visible, "Dash phone stays visible while detailed help remains hidden")
    var phone: Rect2 = game.radar.get_global_rect()
    check(phone.end.x <= 1280 and phone.end.y <= bounds.end.y and phone.end.y >= bounds.position.y, "Phone cradle attaches to dashboard within viewport")
    check(game.radar.point(Vector2.ZERO) == game.radar.MAP.position + Vector2(8, 8), "Sector map fits inside handset screen")
    var floor_on_screen: Vector2 = game.get_global_transform_with_canvas() * Vector2(1100, game.FLOOR)
    check(floor_on_screen.y < bounds.position.y - 20, "Bottom world boundary remains above dashboard")
    var phone_top: float = game.radar.get_global_rect().position.y
    check(floor_on_screen.y < phone_top, "Dash phone also clears the bottom flight boundary")
    await create_timer(0.55).timeout
    check(game.telemetry.current == "00000016" and game.telemetry.roll == 1.0, "Account drums settle on actual signed balance")
    var counter := preload("res://scripts/mechanical_counter.gd").new()
    counter.digits = 3
    counter.text = "₡009"
    game.hud.add_child(counter)
    counter.set_process(false)
    counter._process(0)
    counter.text = "₡010"
    counter._process(0)
    counter._process(counter.ROLL_SECONDS * 0.5)
    var drum: Dictionary = counter.drum_state(2)
    check(drum["from"] == "9" and drum["to"] == "0" and absf(float(drum["fraction"]) - 0.5) < 0.01, "Rollover visibly scrolls nine into zero")
    check(counter.drum_state(1)["fraction"] > 0, "Carry scrolls the tens drum at the same time")
    counter.text = "₡011"
    counter._process(0.01)
    check(counter.current == "010" and counter.roll > 0.5, "New readings queue without resetting an active scroll")
    check(counter.DRUM_COLOR == Color("080a0b") and counter.NUMBER_COLOR == Color("f4f5f1"), "Counter drums are black with white numerals")
    counter._process(counter.ROLL_SECONDS)
    counter._process(counter.ROLL_SECONDS)
    counter.text = "₡010"
    counter._process(0)
    counter._process(counter.ROLL_SECONDS * 0.5)
    check(counter.direction == -1 and counter.drum_state(2)["from"] == "1" and counter.drum_state(2)["to"] == "0", "Decreasing fare or balance rolls drums in reverse")
    counter.free()
    if DisplayServer.get_name() != "headless":
        DirAccess.make_dir_recursive_absolute("res://.development")
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://.development/dashboard-preview.png")
        game.telemetry.set_process(false)
        game.telemetry.text = "₡%06d" % (game.credits + 1)
        game.telemetry._process(0)
        game.telemetry._process(game.telemetry.ROLL_SECONDS * 0.5)
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://.development/dashboard-scroll-preview.png")
        game.telemetry.text = "₡%06d" % game.credits
        game.telemetry._process(game.telemetry.ROLL_SECONDS)
        game.telemetry._process(game.telemetry.ROLL_SECONDS)
        game.telemetry.set_process(true)
    game.help_button.pressed.emit()
    await process_frame
    check(paused and game.overlay.visible and not game.radar.visible, "Handbook pauses flight and hides handset")
    check(game.overlay_copy.text.contains("Fuel burns even while parked") and game.overlay_copy.text.contains("STEER"), "Help includes controls and gameplay information")
    check(game.overlay_panel.get_global_rect().position.y >= 0 and game.overlay_panel.get_global_rect().end.y <= 720, "Handbook fits inside viewport")
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://.development/dashboard-help-preview.png")
    game._resume()
    check(not paused and game.radar.visible and not game.overlay.visible, "Resume restores dash phone with driving view")
    game._start_level()
    game.taxi.set_physics_process(false)
    check(is_equal_approx(game.distance_meters, driven_distance), "Replacing taxi for a sector or retry preserves run distance")
    game._new_game()
    check(game.distance_meters == 0.0, "New run resets odometer")
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    await create_timer(0.2).timeout
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix):
            DirAccess.remove_absolute(PROFILE + suffix)
    print("Taxi dashboard: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
