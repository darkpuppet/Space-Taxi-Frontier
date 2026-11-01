extends SceneTree
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
    game.save_file = "user://frontier_abduction_test.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.level = 10
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(not game.abductions.enabled, "Abductors never spawn before Level 12")
    game.abductions.advance(100)
    check(game.abductions.state == "idle", "Early levels remain free of abduction events")
    game.level = 11
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var raid: Node = game.abductions
    check(raid.enabled and raid.countdown >= 18, "Later levels enable randomized arrivals after a grace period")
    raid.rng.seed = 71829
    raid.countdown = 0
    raid.advance(0.01)
    check(raid.state == "approach" and not raid.target.is_empty(), "Random UFO arrival selects a waiting passenger")
    var id: int = int(raid.target["id"])
    var pad: int = int(raid.target["source"])
    check(pad != game.taxi.landed_on, "Raid never starts against a passenger at the taxi's dock")
    var start: Vector2 = raid.position_in_world
    raid.advance(0.5)
    check(raid.position_in_world != start and raid.state == "approach", "UFO visibly flies toward its target")
    raid.position_in_world = raid.hover
    raid.advance(0.01)
    check(raid.state == "hover" and not raid.target.get("abducting", false), "UFO hovers before grabbing the passenger")
    var credits: int = game.credits
    raid.advance(2.5)
    check(raid.state == "lift" and raid.target.get("abducting", false), "Tractor beam engages only after the hover warning")
    check(not game.dispatcher.board(pad), "A passenger in the tractor beam cannot also board the taxi")
    var patience: float = raid.target["patience"]
    game.dispatcher.tick(0.5, 1, game.taxi.position)
    check(raid.target["patience"] == patience, "Lifted passengers cannot expire during their abduction")
    paused = true
    var age: float = raid.age
    raid.advance(1.0)
    check(raid.age == age and game.credits == credits, "Pause freezes the lift and prevents penalties")
    paused = false
    raid.advance(1.5)
    check(raid.state == "lift" and game.credits == credits, "Passenger visibly struggles during the lift before any penalty")
    # Optional graphical run records a reviewable mid-lift preview.
    if DisplayServer.get_name() != "headless":
        game.camera.position_smoothing_enabled = false
        game.camera.global_position = raid.hover + Vector2(0, 65)
        game.queue_redraw()
        raid.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://tests/abductions.png")
    var sound_count: int = game.audio.get_child_count()
    raid.advance(1.8)
    check(raid.state == "depart" and game.dispatcher.at_pad(pad).is_empty(), "Passenger disappears inside the UFO and the ship escapes")
    check(game.credits == credits - 300 and game.dispatcher.abducted == 1, "Completed abduction deducts exactly 300 credits and records one loss")
    check(game.audio.get_child_count() == sound_count + 1, "Passenger screams once when taken into the UFO")
    raid.advance(0.1)
    check(game.credits == credits - 300, "Departing UFO cannot charge the player again")
    check(not game.passenger_walk.has(id), "Abduction clears the passenger's platform animation")
    game.dispatcher.tick(4.1, 1, game.taxi.position)
    check(game.dispatcher.waiting.size() == game.dispatcher.max_waiting, "Replacement fares keep the mission completable")
    raid.advance(4.0)
    check(raid.state == "idle" and raid.countdown >= 22, "Departed UFO leaves a randomized cooldown before the next raid")
    raid.countdown = 0
    raid.advance(0.01)
    var rescue_pad: int = raid.target["source"]
    game.taxi.landed_on = rescue_pad
    raid.advance(0.01)
    check(raid.state == "depart" and game.credits == credits - 300, "Landing before the lift sends the UFO away without a fine")
    check(game.dispatcher.board(rescue_pad), "A rescued passenger can board normally")
    game.dispatcher.finish()
    game.taxi.landed_on = 1
    raid.reset()
    raid.countdown = 0
    raid.advance(0.01)
    raid.position_in_world = raid.hover
    raid.advance(0.01)
    raid.advance(2.5)
    game.mission_done = true
    raid.advance(0.1)
    check(raid.state == "idle" and game.credits == credits - 300, "Mission completion cancels an in-progress raid without a penalty")
    for fare in game.dispatcher.waiting:
        check(not fare.get("abducting", false), "Cancelling a raid releases its passenger")
    game.mission_done = false
    raid.countdown = 0
    raid.advance(0.01)
    raid.position_in_world = raid.hover
    raid.advance(0.01)
    raid.advance(2.5)
    game._explode_taxi()
    check(raid.state == "idle" and game.credits == credits - 300, "Taxi destruction immediately cancels the lift without an extra fine")
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    if FileAccess.file_exists("user://frontier_abduction_test.cfg"):
        DirAccess.remove_absolute("user://frontier_abduction_test.cfg")
    print("Passenger abductions: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
