extends SceneTree
var failures: int = 0
var checks: int = 0
var game: Node
const PROFILE: String = "user://frontier_towing_fuel_test"

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func freeze_simulation() -> void:
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)

func finish_tow() -> void:
    for step in range(2400):
        if game.tow_truck.state in ["depart", "idle"]:
            break
        game.tow_truck.advance(1.0 / 60)
    check(game.tow_truck.state == "depart", "Tow completes within 40 seconds")

func station(capacity: float, fuel: float, money: int, price: int) -> void:
    game.taxi.fuel_capacity = capacity
    game.taxi.fuel = fuel
    game.taxi.landed_on = 2
    game.taxi.input_locked = false
    game.credits = money
    game.fuel_price = price
    game.fuel_price_clock = 0.0
    game.fuel_meter = 0.0
    game.fuel_session_complete = false

func capture(name: String) -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--preview-dir=") and DisplayServer.get_name() != "headless":
            game.camera.position_smoothing_enabled = false
            game.camera.position = game.taxi.position
            game.queue_redraw()
            game.tow_truck.queue_redraw()
            await process_frame
            await RenderingServer.frame_post_draw
            var path: String = argument.trim_prefix("--preview-dir=").path_join(name + ".png")
            check(root.get_texture().get_image().save_png(path) == OK, "Save visual preview " + name)

func _run() -> void:
    game = load("res://Main.tscn").instantiate()
    game.save_file = PROFILE + ".cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    freeze_simulation()
    var ship: Node = game.taxi
    var idle_position: Vector2 = ship.position
    var idle_fuel: float = ship.fuel
    for step in range(600):
        ship._physics_process(1.0 / 60)
    check(ship.position == idle_position and ship.velocity == Vector2.ZERO, "Taxi remains stationary on its starting platform without input")
    check(absf(ship.fuel - (idle_fuel - 5.0)) < 0.001, "Ten seconds parked burns five fuel units to maintain urgency")
    var parked_fuel: float = ship.fuel
    game._show_pause()
    await physics_frame
    await physics_frame
    check(ship.fuel == parked_fuel, "Pausing stops parked fuel consumption")
    game._resume()
    ship.input_locked = true
    ship._physics_process(0.05)
    check(ship.fuel == parked_fuel, "Disabled taxi does not consume idle fuel during recovery")
    ship.input_locked = false
    ship.position = Vector2(1100, 620)
    ship.landed_on = -1
    ship.velocity = Vector2(200, 300)
    ship.hull = 63
    ship.fuel = 0.001
    game.credits = 100
    var rider: Dictionary = game.dispatcher.waiting[0]
    game.dispatcher.board(int(rider["source"]))
    game.passenger_onboard = true
    game.destination_pad = int(rider["destination"])
    var original_position: Vector2 = ship.position
    ship._physics_process(0.05)
    check(game.tow_truck.state == "approach" and ship.input_locked, "Running dry during physics automatically summons the truck")
    check(game.tow_truck.sprite is Sprite2D and game.tow_truck.sprite.visible and game.tow_truck.sprite.hframes == 4, "Truck uses a visible four-frame sprite sheet")
    check(game.tow_truck.sprite.vframes == 2 and game.tow_truck.sprite.frame_coords.y == 1, "Approach uses the powered-flight sprite animation")
    var sprite_frame: int = game.tow_truck.sprite.frame
    game.audio._update_tow_audio(0.1)
    check(game.audio.tow_player.playing and game.audio.tow_player.bus == "FrontierEffects", "Clunker engine starts on the effects bus when the truck appears")
    var clunker: AudioStreamWAV = game.audio.tow_player.stream
    check(clunker.data.size() == 88200 and clunker.loop_mode == AudioStreamWAV.LOOP_FORWARD and clunker.loop_end == 44100, "Clunker is a two-second looping 16-bit engine recording")
    check(clunker.data != game.audio.clunk.data, "Engine rumble is distinct from the impact clunk")
    check(ship.position == original_position and ship.velocity == Vector2.ZERO, "Rescue secures taxi before it can hit hazards")
    check(game.credits == -200 and game.lives == 3, "Tow costs exactly 300 credits, including debt, without losing a life")
    game._request_automatic_tow()
    game._request_tow()
    check(game.credits == -200, "Repeated requests during recovery cannot double-charge")
    var truck_start: Vector2 = game.tow_truck.position
    game.tow_truck.advance(0.1)
    check(game.tow_truck.sprite.frame != sprite_frame, "Thrusters, exhaust puffs, and beacon animate with sprite frames")
    game.audio.toggle_mute()
    game.audio._update_tow_audio(0.1)
    check(game.audio.tow_player.stream_paused, "Mute silences the tow engine")
    game.audio.toggle_mute()
    game.audio._update_tow_audio(0.1)
    check(not game.audio.tow_player.stream_paused, "Unmute restores the active tow engine")
    check(game.tow_truck.position != truck_start and ship.position == original_position, "Truck flies to disabled taxi instead of teleporting it")
    game._show_pause()
    var truck_paused: Vector2 = game.tow_truck.position
    var paused_frame: int = game.tow_truck.sprite.frame
    game._process(2)
    game.tow_truck.advance(2)
    check(game.tow_truck.position == truck_paused and ship.position == original_position, "Pause freezes both vehicles")
    game.audio._update_tow_audio(0.1)
    check(game.audio.tow_player.stream_paused and game.tow_truck.sprite.frame == paused_frame, "Pause freezes sprite animation and clunker playback")
    game._resume()
    for step in range(600):
        game.tow_truck.advance(1.0 / 60)
        if game.tow_truck.state == "hook":
            break
    check(game.tow_truck.state == "hook", "Truck reaches taxi and lowers the hook")
    check(game.tow_truck.sprite.frame_coords.y == 0, "Hookup switches to the quieter hover thrusters")
    game.audio._update_tow_audio(1.0)
    var idle_pitch: float = game.audio.tow_player.pitch_scale
    var idle_volume: float = game.audio.tow_player.volume_db
    await capture("tow-hook")
    var hook_start: float = game.tow_truck.hook_length
    game.tow_truck.advance(0.5)
    check(game.tow_truck.hook_length > hook_start, "Hook visibly lowers toward the car")
    for step in range(180):
        game.tow_truck.advance(1.0 / 60)
        if game.tow_truck.state == "lift":
            break
    check(game.tow_truck.state == "lift" and ship.position == original_position, "Hook reaches the taxi without snapping it to the truck")
    check(is_equal_approx(game.tow_truck.hook_length, ship.position.y - game.tow_truck.position.y - game.tow_truck.TAXI_ROOF), "Hook connects to the taxi roof before lifting")
    var extended_cable: float = game.tow_truck.hook_length
    game.tow_truck.advance(0.5)
    check(ship.position.y < original_position.y and game.tow_truck.hook_length < extended_cable, "Winch visibly reels in the taxi during lift")
    for step in range(600):
        game.tow_truck.advance(1.0 / 60)
        if game.tow_truck.state == "return":
            break
    game.tow_truck.advance(0.1)
    check(ship.position.is_equal_approx(game.tow_truck.position + game.tow_truck.HITCH), "Taxi visibly hangs from the moving tow rig")
    check(game.tow_truck.sprite.frame_coords.y == 1, "Hauling reignites the bright flight thrusters")
    game.audio._update_tow_audio(1.0)
    check(game.audio.tow_player.pitch_scale > idle_pitch and game.audio.tow_player.volume_db > idle_volume, "Clunker revs louder and faster while hauling than while hooking up")
    check(game.tow_truck.driver_line != "" and game.banner.text.begins_with("BUBBA /"), "Driver chatter appears in bubble and cockpit")
    await capture("tow-hauling")
    for step in range(1800):
        game.tow_truck.advance(1.0 / 60)
        if game.tow_truck.state == "lower":
            break
    check(game.tow_truck.state == "lower", "Truck arrives above the fuel pad before lowering")
    check(game.tow_truck.sprite.frame_coords.y == 0, "Setdown uses hover animation while the winch lowers the taxi")
    var hover_position: Vector2 = game.tow_truck.position
    var raised_taxi: Vector2 = ship.position
    game.tow_truck.advance(0.7)
    check(game.tow_truck.position == hover_position and ship.position.y > raised_taxi.y, "Truck hovers while its winch lowers the taxi onto the platform")
    check(is_equal_approx(game.tow_truck.hook_length, ship.position.y - hover_position.y - game.tow_truck.TAXI_ROOF), "Cable remains attached during setdown")
    await capture("tow-lowering")
    finish_tow()
    check(ship.landed_on == 2 and ship.position == Vector2(game.pads[1]["x"], float(game.pads[1]["y"]) - 21), "Taxi is set down on the actual fuel platform")
    check(ship.fuel == 45 and ship.hull == 63 and not ship.input_locked and game.last_landed_pad == 2, "Recovery restores controls and starter fuel, preserving hull")
    check(game.passenger_onboard and game.dispatcher.active == rider, "Tow preserves the passenger and their destination")
    ship.position = Vector2(800, 400)
    ship.landed_on = -1
    ship.fuel = 0
    game._process(0)
    check(game.tow_truck.state == "approach" and game.credits == -500, "Empty tanks remain recoverable after the manual allowance is spent")
    finish_tow()
    game.tow_truck.reset()
    game.audio._update_tow_audio(0.1)
    check(not game.audio.tow_player.playing and not game.tow_truck.sprite.visible, "Engine and sprite stop when the truck is dismissed")
    game.tow_truck.start(ship, Vector2(500, 600))
    game.tow_truck.reset()
    check(not ship.input_locked and game.tow_truck.state == "idle", "Cancelling a rescue releases the taxi controls")
    ship.capture_active = true
    var before_charge: int = game.credits
    game._request_automatic_tow()
    check(game.credits == before_charge and game.tow_truck.state == "idle", "Black-hole capture cannot be escaped by towing")
    ship.capture_active = false
    station(140, 50, 1000, 4)
    game._on_landed(2)
    check(ship.fuel == 50 and game.credits == 1000, "Landing grants no instantaneous free fuel")
    check(ship.fuel_service_active, "Landing immediately connects the taxi to automatic fuel service")
    game._update_fuel_station(1)
    check(is_equal_approx(ship.fuel, 65) and game.credits == 940, "Pump delivers 15 fuel units per second at the displayed price")
    check(is_equal_approx((ship.fuel - 50) * 4, 1000 - game.credits), "Meter charges the current unit price exactly")
    var partial_fuel: float = ship.fuel
    var partial_money: int = game.credits
    ship.landed_on = -1
    game._update_fuel_station(1)
    check(ship.fuel == partial_fuel and game.credits == partial_money, "Taking off immediately stops pumping and billing")
    for capacity in [140.0, 300.0]:
        for price in [2, 10]:
            station(capacity, 0, 10000, price)
            var elapsed: float = 0.0
            for step in range(1212):
                elapsed += 1.0 / 60
                game._update_fuel_station(1.0 / 60)
                ship._physics_process(1.0 / 60)
                if game.fuel_session_complete:
                    break
            var expected_seconds: float = capacity / 15.0
            check(game.fuel_session_complete and absf(elapsed - expected_seconds) < 0.04 and elapsed <= 20.000001, "Fill duration follows fixed flow: 9.3 seconds stock and 20 seconds fully upgraded")
            check(ship.fuel >= capacity - ship.idle_fuel_drain / 60 - 0.000001, "Meter reaches a completed full tank")
            check(game.credits > 0, "Funded fill does not consume unrelated credits")
    for capacity in [140.0, 180.0, 220.0, 260.0, 300.0]:
        station(capacity, 0, 10000, 4)
        game._update_fuel_station(1)
        check(is_equal_approx(ship.fuel, 15) and game.credits == 9940, "Pump rate is independent of every tank upgrade")
    station(140, 50, 3, 10)
    game._update_fuel_station(1)
    check(game.credits == 0 and is_equal_approx(ship.fuel, 50.3), "Last credits buy fractional fuel without overspending")
    game._update_fuel_station(5)
    check(is_equal_approx(ship.fuel, 50.3), "Empty wallet stops the pump")
    station(140, 50, -20, 2)
    game._update_fuel_station(1)
    check(ship.fuel == 50 and game.credits == -20, "Pump never puts a player into debt")
    station(140, 139.8, 100, 4)
    game._update_fuel_station(1)
    check(ship.fuel == 140 and game.credits == 99, "Final fractional fill clamps to capacity and rounds to one credit")
    game._update_fuel_station(5)
    check(game.credits == 99, "Full tank incurs no further charges")
    for step in range(120):
        ship._physics_process(1.0 / 60)
        game._update_fuel_station(1.0 / 60)
    check(game.credits == 99 and game.fuel_session_complete, "Idling after a completed fill cannot incur repeated rounded top-off charges")
    check(ship.fuel == ship.fuel_capacity, "A completed tank stays full while parked at the fuel platform")
    station(140, 139, 4, 4)
    game._on_landed(2)
    for step in range(120):
        game._process(1.0 / 60)
        ship._physics_process(1.0 / 60)
    check(ship.fuel == 140 and game.credits == 0, "Automatic filling stops at full even when the final purchase spends the last credit")
    station(140, 50, 12, 4)
    game._on_landed(2)
    for step in range(60):
        game._process(1.0 / 60)
    check(is_equal_approx(ship.fuel, 53) and game.credits == 0, "Normal gameplay pumps continuously after landing until the wallet is empty")
    station(140, 50, 1000, 2)
    game._show_pause()
    game._update_fuel_station(60)
    check(ship.fuel == 50 and game.credits == 1000 and game.fuel_price == 2, "Pause freezes pumping, charges, and market price")
    game._resume()
    ship.landed_on = -1
    var prices: Dictionary = {}
    seed(7814)
    for step in range(100):
        var previous: int = game.fuel_price
        game._update_fuel_station(30)
        check(game.fuel_price >= 2 and game.fuel_price <= 10 and game.fuel_price != previous, "Market changes price within 2-10 credits")
        prices[game.fuel_price] = true
    check(prices.has(2) and prices.has(10), "Price range includes both endpoints")
    station(140, 0, 1000, 2)
    ship._physics_process(0.05)
    check(game.tow_truck.state == "idle" and not ship.input_locked, "A funded taxi already at the pump does not incur a needless tow")
    game._process(1)
    check(ship.fuel > 0 and game.credits < 1000, "Empty taxi at fuel pad starts paid refueling")
    game._save_game()
    var paid_balance: int = game.credits
    game.credits = 0
    game._load_game()
    check(game.credits == paid_balance, "Pump charges persist in the career save")
    await capture("fuel-price-sign")
    game._request_tow(true)
    game._start_level()
    freeze_simulation()
    check(game.tow_truck.state == "idle" and not game.taxi.input_locked, "Restart discards the old rescue and unlocks the replacement taxi")
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    await create_timer(0.2).timeout
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix):
            DirAccess.remove_absolute(PROFILE + suffix)
    print("Towing and paid fuel: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
