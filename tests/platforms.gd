extends SceneTree
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
    var previous: Array = []
    for level in range(20):
        var pads: Array = CAMPAIGN.pads_for(level)
        check(pads[1]["services"].has("upgrades"), "Every sector has a dedicated upgrade dock at PAD 02")
        var widths: Dictionary = {}
        for index in range(5):
            widths[pads[index]["width"]] = true
            if not previous.is_empty():
                check(pads[index]["width"] < previous[index]["width"], "Platform narrows from the previous sector")
        check(widths.size() == 5, "Every sector has five distinct platform widths")
        previous = pads
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_platform_test.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var ship: CharacterBody2D = game.taxi
    var pad: Dictionary = game.pads[0]
    var edge: float = float(pad["x"]) + float(pad["width"]) * 0.5
    ship.environment = null
    ship.landed_on = -1
    ship.position = Vector2(edge - 5, float(pad["y"]) - 23)
    ship.velocity = Vector2(0, 130)
    ship._physics_process(1.0 / 60)
    check(ship.landed_on == 1 and ship.support_fraction(pad, ship.position.x) > 0.5, "Slightly more than half the taxi supported permits landing")
    ship.position.x = edge
    ship._physics_process(1.0 / 60)
    check(ship.landed_on == -1, "Exactly half supported does not lock the taxi onto a pad")
    for step in range(90):
        ship._physics_process(1.0 / 60)
    check(ship.position.x > edge + 37 and ship.position.y > float(pad["y"]) + 20, "Unsupported taxi slides past the edge and falls")
    ship.position = Vector2(edge - 5, float(pad["y"]) - 21)
    ship.velocity = Vector2.ZERO
    ship.landed_on = 1
    Input.action_press("move_right")
    for step in range(15):
        ship._physics_process(1.0 / 60)
    Input.action_release("move_right")
    check(ship.landed_on == -1, "Ground steering can move the taxi beyond safe support")
    game.level = 2
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    ship = game.taxi
    var victim: Dictionary = game.dispatcher.waiting[0]
    var victim_id: int = int(victim["id"])
    var other_id: int = int(game.dispatcher.waiting[1]["id"])
    pad = game.pads[int(victim["source"]) - 1]
    game.credits = 1000
    ship.environment = null
    ship.landed_on = -1
    ship.position = Vector2(game._fare_home_x(pad), float(pad["y"]) - 120)
    ship.velocity = Vector2(0, 300)
    for step in range(8):
        ship._physics_process(0.05)
    check(game.dispatcher.killed == 1 and game.credits == 750, "Actual descending taxi kills the struck fare and applies one 250-credit fine")
    check(game.dispatcher.waiting.size() == 1 and game.dispatcher.waiting[0]["id"] == other_id, "Passenger collision leaves the other waiting fare intact")
    check(not game.passenger_walk.has(victim_id) and not game.passenger_onboard and game.deliveries == 0 and game.lives == 3, "Passenger death removes boarding state without awarding a delivery or taking a taxi life")
    check(not game.passenger_accidents[0]["alien"] and game.passenger_accidents[0]["color"].r > game.passenger_accidents[0]["color"].g, "Human casualty creates red splatter")
    var squish: AudioStreamWAV = game.audio._squish_sound()
    var squish_voices: int = 0
    for voice in game.audio.get_children():
        if voice is AudioStreamPlayer and voice.stream is AudioStreamWAV and voice.stream.data == squish.data:
            squish_voices += 1
    check(squish_voices == 1 and squish.data.size() == 14112, "Passenger impact plays the distinct squish sound exactly once")
    var human_scream: AudioStreamWAV = game.audio._passenger_scream(false)
    var alien_scream: AudioStreamWAV = game.audio._passenger_scream(true)
    check(human_scream.data != alien_scream.data, "Human and alien screams have distinct voices")
    for scream in [human_scream, alien_scream]:
        check(scream.mix_rate == 22050 and scream.format == AudioStreamWAV.FORMAT_16_BITS and not scream.stereo, "Screams use valid mono PCM")
        var energy: float = 0.0
        var peak: int = 0
        for byte in range(0, scream.data.size(), 2):
            var sample: int = scream.data.decode_s16(byte)
            energy += float(sample) * sample
            peak = maxi(peak, absi(sample))
        check(sqrt(energy / (scream.data.size() / 2)) > 1500 and peak < 30000, "Screams are audible and have clipping headroom")
        check(absi(scream.data.decode_s16(0)) < 10 and absi(scream.data.decode_s16(scream.data.size() - 2)) < 10, "Scream envelopes start and finish without clicks")
    check(human_scream.get_length() > 0.4 and human_scream.get_length() < 0.5 and alien_scream.get_length() < 0.55, "Passenger yelps stay brief")
    var human_yelps: int = 0
    for voice in game.audio.get_children():
        if voice is AudioStreamPlayer and voice.stream == human_scream:
            human_yelps += 1
            check(voice.pitch_scale >= 0.95 and voice.pitch_scale <= 1.08, "Small pitch variation keeps screams lively")
    check(human_yelps == 1, "Landing on a human plays one human scream alongside the squish")
    var start := Vector2(game._fare_home_x(pad), float(pad["y"]) - 150)
    var finish := Vector2(start.x, float(pad["y"]) - 21)
    game._on_taxi_flight_motion(start, finish)
    check(game.credits == 750 and game.dispatcher.killed == 1, "Repeated contact cannot charge a fine for the same fare twice")
    var repeated_yelps: int = 0
    for voice in game.audio.get_children():
        if voice is AudioStreamPlayer and voice.stream == human_scream:
            repeated_yelps += 1
    check(repeated_yelps == human_yelps, "Repeated contact never repeats a dead passenger's scream")
    game._update_passenger_accidents(3.9)
    check(game.passenger_accidents.size() == 1, "Grave stays visible until dispatch supplies a replacement")
    game._show_pause()
    game._process(10)
    check(is_equal_approx(game.passenger_accidents[0]["age"], 3.9), "Pause freezes splatter and grave timing")
    game._resume()
    game.dispatcher.tick(3.9, int(victim["source"]), ship.position)
    check(game.dispatcher.waiting.size() == 1, "Killed fare is not replaced instantly")
    game.dispatcher.tick(0.2, int(victim["source"]), ship.position)
    check(game.dispatcher.waiting.size() == 2, "Dispatch replaces a killed fare so the level remains completable")
    game._update_passenger_accidents(0.2)
    check(game.passenger_accidents.size() == 1 and game.passenger_accidents[0].has("dissolve_age"), "Replacement passenger starts the grave dissolve")
    game._update_passenger_accidents(0.4)
    var dissolve_age: float = game.passenger_accidents[0]["dissolve_age"]
    game._update_passenger_accidents(0)
    check(game.passenger_accidents[0]["dissolve_age"] == dissolve_age, "Dispatch refresh does not restart or advance the dissolve")
    game._show_pause()
    game._process(10)
    check(game.passenger_accidents[0]["dissolve_age"] == dissolve_age, "Pause freezes the grave dissolve")
    game._resume()
    game._update_passenger_accidents(0.51)
    check(game.passenger_accidents.is_empty(), "Grave clears after its dissolve finishes")
    victim = game.dispatcher.waiting[0]
    pad = game.pads[int(victim["source"]) - 1]
    game.credits = 0
    start = Vector2(game._fare_home_x(pad), float(pad["y"]) - 150)
    finish = Vector2(start.x, float(pad["y"]) - 21)
    game._on_taxi_flight_motion(start, finish)
    check(game.credits == -250, "A passenger fine still loses money when the cab has no credits")
    game._on_taxi_flight_motion(finish, start)
    check(game.credits == -250, "Ascending flight cannot trigger a landing fatality")
    game.level = 1
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(game.passenger_accidents.is_empty(), "Restart clears old memorials")
    victim = game.dispatcher.waiting[0]
    pad = game.pads[int(victim["source"]) - 1]
    start = Vector2(game._fare_home_x(pad), float(pad["y"]) - 150)
    finish = Vector2(start.x, float(pad["y"]) - 21)
    game._on_taxi_flight_motion(start, finish)
    check(game.passenger_accidents.size() == 1 and game.passenger_accidents[0]["alien"] and game.passenger_accidents[0]["color"].g > game.passenger_accidents[0]["color"].r, "Alien casualty creates green splatter matching the rider sprite")
    var alien_yelps: int = 0
    for voice in game.audio.get_children():
        if voice is AudioStreamPlayer and voice.stream == alien_scream:
            alien_yelps += 1
    check(alien_yelps == 1, "Landing on an alien plays its distinct alien scream")
    game.dispatcher.refill(1, Vector2.ZERO)
    game._update_passenger_accidents(1)
    check(game.passenger_accidents.size() == 1, "Grave has a minimum few-second display even if dispatch refills early")
    game._update_passenger_accidents(2.1)
    check(game.passenger_accidents.size() == 1 and game.passenger_accidents[0].has("dissolve_age"), "Early replacement grave dissolves after its minimum display time")
    game._update_passenger_accidents(1)
    check(game.passenger_accidents.is_empty(), "Completed dissolve removes the early replacement grave")
    var memorial_art = preload("res://scripts/passenger_accident_fx.gd")
    memorial_art.prepare()
    check(memorial_art.frames.size() == 4 and memorial_art.ATLAS.get_image().detect_alpha() != Image.ALPHA_NONE, "Splatter, splash and grave sprites load with transparency")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    print("Platforms and passenger strikes: %d failures" % failures)
    quit(0 if failures == 0 else 1)
