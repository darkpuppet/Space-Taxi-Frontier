extends SceneTree
const DISPATCH = preload("res://scripts/fares.gd")
const CAMPAIGN = preload("res://scripts/campaign.gd")
const TYPES = preload("res://scripts/passenger_types.gd")
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
    var arrivals = preload("res://scripts/passenger_arrivals.gd").new()
    var lift_image: Image = arrivals.ATLAS.get_image()
    check(lift_image.detect_alpha() != Image.ALPHA_NONE, "Elevator sprite atlas preserves transparency")
    check(lift_image.get_pixel(315, 316).a < 0.15, "Rear cabin interior leaves the passenger visible")
    for region in [arrivals.REAR_REGION] + arrivals.DOOR_REGIONS:
        check(Rect2(Vector2.ZERO, arrivals.ATLAS.get_size()).encloses(region), "Elevator layers use valid source regions")
        check(lift_image.get_region(Rect2i(region)).get_used_rect().has_area(), "Each elevator layer contains painted sprite artwork")
    var lift_pad: Dictionary = CAMPAIGN.pads_for(0)[0]
    check(arrivals.lifts_for(int(lift_pad["id"])).is_empty(), "Idle platforms have no visible elevator")
    arrivals.prepare(lift_pad, Vector2(float(lift_pad["x"]) - 20.0, float(lift_pad["y"]) - 100.0))
    check(arrivals.lifts_for(int(lift_pad["id"])).size() == 1 and float(arrivals.expected["target"]) > float(lift_pad["x"]), "Expected drop-off deploys one lift opposite the approaching cab")
    arrivals.advance(0.5)
    check(float(arrivals.expected["rise"]) > 0.0 and float(arrivals.expected["rise"]) < 1.0, "Lift rises gradually from inside the pad")
    check(arrivals.lifts_for(3).is_empty(), "Other platforms remain free of elevators")
    var rise_before_landing: float = float(arrivals.expected["rise"])
    arrivals.drop_off(lift_pad, float(lift_pad["x"]) - 20.0, 0)
    check(arrivals.expected.is_empty() and is_equal_approx(float(arrivals.riders[0]["rise"]), rise_before_landing), "Landing continues the prepared lift without a second cabin")
    arrivals.reset()
    arrivals.prepare(lift_pad, Vector2(float(lift_pad["x"]) + 20.0, float(lift_pad["y"]) - 100.0))
    check(float(arrivals.expected["target"]) < float(lift_pad["x"]), "A cab on the right deploys the lift on the left")
    arrivals.prepare(lift_pad, Vector2(float(lift_pad["x"]), float(lift_pad["y"]) - 500.0))
    check(arrivals.expected.is_empty(), "Lift stays hidden while the taxi is far from its destination")
    arrivals.reset()
    for level_index in range(20):
        for pad in CAMPAIGN.pads_for(level_index):
            for offset in [-15.0, 15.0]:
                var center: float = float(pad["x"])
                arrivals.drop_off(pad, center + offset, 0)
                var target: float = float(arrivals.riders.back()["target"])
                check((target - center) * offset < 0.0, "Arrivals head to the opposite side of the platform")
                check(absf(target - center) < float(pad["width"]) * 0.5, "Elevator destination stays on the platform in every sector")
                check(absf(target - center) + 30.0 <= float(pad["width"]) * 0.5, "Full painted cabin stays within the platform edges")
                arrivals.riders.clear()
    var dispatch = DISPATCH.new()
    for level_index in range(20):
        var seen: Dictionary = {}
        for fare_id in range(1, 31):
            var variant: int = TYPES.for_fare(level_index, fare_id)
            check(int(TYPES.TYPES[variant]["unlock"]) <= level_index + 1, "Passenger type never appears before its introduction")
            seen[variant] = true
        check(seen.size() == TYPES.available_count(level_index), "Later levels retain every unlocked passenger type")
    for debut in [5, 10, 15]:
        check(TYPES.for_fare(debut, 1) == TYPES.available_count(debut) - 1, "First fare introduces the new passenger on its debut level")
    for level in range(20):
        dispatch.configure(level, CAMPAIGN.pads_for(level))
        dispatch.refill(1, Vector2(240, 569))
        check(dispatch.waiting.size() == (1 if level < 2 else 2), "Level %02d has the correct concurrent fare count" % (level + 1))
        for fare in dispatch.waiting:
            check(fare["variant"] == TYPES.for_fare(level, int(fare["id"])), "Passenger appearance is assigned when the fare spawns")
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
        var delivered_variant: int = game._passenger_variant(game.dispatcher.active)
        game._process(0.25)
        check(game.passenger_arrivals.lifts_for(destination).size() >= 1, "An occupied taxi deploys its destination lift before drop-off")
        game._on_landed(destination)
        check(not game.passenger_arrivals.riders.is_empty(), "Delivered passenger exits the taxi instead of disappearing")
        check(game.passenger_arrivals.riders.back()["variant"] == delivered_variant, "Drop-off retains the passenger's original appearance")
        game._process(0.1)
        if index < 2:
            check(not game.gate_active and game.source_pad != destination, "Next rider requires a different pickup and gate remains closed")
    check(game.gate_active and game.mission_done and game.level == 0, "Last fare opens the star gate without advancing automatically")
    var arrival: Dictionary = game.passenger_arrivals.riders.back()
    var arrival_x: float = float(arrival["x"])
    var paid_deliveries: int = game.deliveries
    game._show_pause()
    game._process(1.0)
    check(float(arrival["x"]) == arrival_x, "Pause freezes the passenger's walk to the elevator")
    game._resume()
    game.taxi.landed_on = -1
    game.taxi.position = Vector2(300, 200)
    for step in range(600):
        game._process(1.0 / 60.0)
        if arrival["state"] == "closing":
            break
    check(arrival["state"] == "closing" and is_equal_approx(float(arrival["x"]), float(arrival["target"])), "Passenger reaches the opposite end even after the taxi departs")
    game._process(0.61)
    check(arrival["state"] == "descending", "Elevator closes its doors before descending")
    game._show_pause()
    var lift_age: float = float(arrival["age"])
    game._process(2.0)
    check(float(arrival["age"]) == lift_age, "Pause freezes the elevator descent")
    game._resume()
    game._process(1.41)
    check(game.passenger_arrivals.riders.is_empty() and game.deliveries == paid_deliveries, "Elevator removes completed arrivals without awarding the fare twice")
    for pad in game.pads:
        check(game.passenger_arrivals.lifts_for(int(pad["id"])).is_empty(), "Retracted elevators leave every pad clear")
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
    game.passenger_arrivals.drop_off(game.pads[0], float(game.pads[0]["x"]), 0)
    game._process(0.1)
    check(game.level == 1 and not game.gate_active, "Flying through the gate advances and closes it in the new level")
    check(game.passenger_arrivals.riders.is_empty(), "Changing levels clears passengers and elevator animations")
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
