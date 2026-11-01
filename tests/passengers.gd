extends SceneTree
const DISPATCH = preload("res://scripts/fares.gd")
const CAMPAIGN = preload("res://scripts/campaign.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    if value:
        print("PASS: " + description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func _run() -> void:
    var dispatch = DISPATCH.new()
    for level in range(20):
        dispatch.configure(level, CAMPAIGN.pads_for(level))
        dispatch.refill(1, Vector2(240, 569))
        check(dispatch.waiting.size() == (1 if level < 2 else 2), "Level %02d has the correct concurrent fare count" % (level + 1))
        for fare in dispatch.waiting:
            check(fare["source"] != 1 and fare["source"] != fare["destination"], "Riders never spawn on the taxi pad or request the same destination")
            for other in dispatch.waiting:
                check(fare["destination"] != other["source"], "Dropoff pads have no waiting rider ready for an instant next trip")
    # Repeated mission completion and expiry must never put fares on service pads.
    for level in range(20):
        var terminals: Array = CAMPAIGN.pads_for(level)
        dispatch.configure(level, terminals)
        var excluded: int = 1
        for trip in range(24):
            dispatch.refill(excluded, Vector2(terminals[excluded - 1]["x"], terminals[excluded - 1]["y"]))
            check(not dispatch.waiting.is_empty(), "Terminal-only dispatch remains available throughout the campaign")
            for rider in dispatch.waiting:
                check(terminals[int(rider["source"]) - 1]["services"].is_empty() and terminals[int(rider["destination"]) - 1]["services"].is_empty(), "New and replacement fares use terminal platforms only")
            if trip % 3 == 0:
                dispatch.tick(100, excluded, Vector2.ZERO)
                dispatch.tick(4.1, excluded, Vector2.ZERO)
            else:
                var rider: Dictionary = dispatch.waiting[0]
                excluded = int(rider["destination"])
                dispatch.board(int(rider["source"]))
                dispatch.finish()
    var service_fixture: Array = CAMPAIGN.pads_for(0)
    service_fixture[1]["services"] = ["fuel"]
    service_fixture[3]["services"] = ["repair"]
    dispatch.configure(2, service_fixture)
    for trip in range(12):
        dispatch.refill(1, Vector2.ZERO)
        for rider in dispatch.waiting:
            check(int(rider["source"]) not in [2, 4] and int(rider["destination"]) not in [2, 4], "Separate fuel-only and repair-only pads are excluded from fares")
        dispatch.tick(100, 1, Vector2.ZERO)
    dispatch.configure(2, CAMPAIGN.pads_for(2))
    dispatch.refill(1, Vector2(240, 569))
    var chosen: Dictionary = dispatch.waiting[1].duplicate(true)
    check(dispatch.board(chosen["source"]) and dispatch.active["id"] == chosen["id"], "Player can pick either waiting fare by landing at its pad")
    var departed: Array[int] = dispatch.tick(100, chosen["source"], Vector2(700, 450))
    check(departed.size() == 1 and dispatch.waiting.is_empty() and dispatch.missed == 1, "Impatient waiting rider leaves when time expires")
    check(not dispatch.active.is_empty(), "Onboard passengers stay aboard while other waiting fares expire")
    dispatch.tick(3, chosen["source"], Vector2(700, 450))
    check(dispatch.waiting.is_empty(), "Departed riders do not instantly respawn")
    dispatch.tick(1.1, chosen["source"], Vector2(700, 450))
    check(not dispatch.waiting.is_empty(), "Dispatch replaces departed fares after a short delay")
    for fare in dispatch.waiting:
        check(fare["source"] != chosen["source"] and fare["source"] != chosen["destination"], "Replacement riders avoid both the taxi's pad and active dropoff")
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_dispatch_test.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var patience: float = game.dispatcher.waiting[0]["patience"]
    var animation_clock: float = game.pulse
    game._show_pause()
    game._process(10)
    check(game.dispatcher.waiting[0]["patience"] == patience, "Pausing freezes rider patience")
    check(game.pulse == animation_clock, "Pausing freezes impatient foot tapping")
    game._resume()
    game._process(0.1)
    check(game.pulse > animation_clock, "Resuming advances the passenger animation clock")
    # Test movement independently of the dispatcher recommendation and boarding timer.
    game.level = 2
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var walker: Dictionary = game.dispatcher.waiting[1]
    var walker_id: int = int(walker["id"])
    var walker_pad: Dictionary = game.pads[int(walker["source"]) - 1]
    var home_x: float = float(walker_pad["x"]) + 46
    var other_id: int = int(game.dispatcher.waiting[0]["id"])
    game.taxi.landed_on = int(walker["source"])
    game.taxi.position = Vector2(float(walker_pad["x"]) - 35, float(walker_pad["y"]) - 21)
    game._on_landed(game.taxi.landed_on)
    game._process(0.25)
    var walking_x: float = float(game.passenger_walk[walker_id]["x"])
    check(walking_x < home_x and walking_x > game.taxi.position.x and not game.passenger_onboard, "Rider walks toward the actual taxi position before boarding")
    check(game.passenger_walk[walker_id]["moving"] and game.passenger_walk[walker_id]["direction"] == -1, "Walking rider faces the taxi")
    check(not game.passenger_walk[other_id]["moving"], "Other waiting fares stay at their own platforms")
    game._show_pause()
    game._process(1)
    check(game.passenger_walk[walker_id]["x"] == walking_x, "Pause freezes the boarding walk")
    game._resume()
    game.taxi.landed_on = -1
    game._process(0.1)
    check(game.passenger_walk[walker_id]["x"] > walking_x and not game.passenger_onboard and game.boarding_time == 0, "Early takeoff cancels boarding and rider walks back")
    game._process(1)
    check(is_equal_approx(game.passenger_walk[walker_id]["x"], home_x), "Returning rider reaches the original waiting spot without teleporting")
    game.taxi.landed_on = int(walker["source"])
    for step in range(80):
        game._process(1.0 / 60)
    check(game.passenger_onboard and int(game.dispatcher.active["id"]) == walker_id, "Either fare boards only after walking all the way to the taxi")
    check(not game.passenger_walk.has(walker_id), "Boarded rider no longer has a platform sprite")
    game.level = 0
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    walker = game.dispatcher.waiting[0]
    walker_id = int(walker["id"])
    game.taxi.landed_on = int(walker["source"])
    game.taxi.position = Vector2(game.pads[game.taxi.landed_on - 1]["x"], game.pads[game.taxi.landed_on - 1]["y"] - 21)
    walker["patience"] = 0.2
    game._process(0.1)
    game._process(0.11)
    check(not game.passenger_walk.has(walker_id) and not game.passenger_onboard, "An expired fare leaves cleanly during the approach")
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(game.passenger_walk.is_empty(), "Restart clears walking positions from the previous level")
    check(not game.gate_active, "Star gate is absent before the final fare")
    game._enter_star_gate()
    check(game.level == 0, "Gate cannot advance an unfinished level")
    for index in range(3):
        var pickup: int = game.source_pad
        game.taxi.landed_on = pickup
        game.taxi.position = Vector2(game.pads[pickup - 1]["x"], game.pads[pickup - 1]["y"] - 21)
        game._on_landed(pickup)
        game._process(1.1)
        var destination: int = game.destination_pad
        game.taxi.landed_on = destination
        game.taxi.position = Vector2(game.pads[destination - 1]["x"], game.pads[destination - 1]["y"] - 21)
        game._on_landed(destination)
        game._process(0.1)
        if index < 2:
            check(not game.gate_active and game.source_pad != destination, "Next rider requires a different pickup and gate remains closed")
    check(game.gate_active and game.mission_done and game.level == 0, "Last fare opens the star gate without advancing automatically")
    check(is_instance_valid(game.gate_fx) and game.gate_fx.position == game.gate_position, "Particle gate is placed at the actual randomized exit")
    var mote: Vector2 = game.gate_fx.vortex_point(17)
    game._process(0.25)
    check(game.gate_fx.vortex_point(17).distance_to(mote) > 1, "Vortex particles move while the gate is active")
    for particle in range(game.gate_fx.VORTEX_COUNT):
        check(game.gate_fx.vortex_point(particle).length() <= 103, "Vortex particles stay within their bounded visual field")
    var gate_age: float = game.gate_fx.age
    game._show_pause()
    game._process(1)
    check(game.gate_fx.age == gate_age, "Pause freezes gate particle animation")
    game._resume()
    game.taxi.position = game.gate_position
    game.taxi.landed_on = 1
    game._process(0.1)
    check(game.level == 0, "Taxi must be airborne to enter the gate")
    game.taxi.landed_on = -1
    game._process(0.1)
    check(game.level == 1 and not game.gate_active, "Flying through the gate advances and closes it in the new level")
    check(game.gate_fx == null and game.gate_warp.age < game.gate_warp.DURATION, "Entry clears the old particle gate and starts the warp burst")
    game._process(0.5)
    check(game.gate_warp.age == game.gate_warp.DURATION, "Warp burst clears itself after the transition")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    print("Passenger dispatch and star gates: %d failures" % failures)
    quit(0 if failures == 0 else 1)
