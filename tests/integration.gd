extends SceneTree
## Integration checks run against an isolated save; never touch the pilot's career.
var failures: int = 0
var game: Node
const TEST_SAVE: String = "user://frontier_integration_test.cfg"

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, description: String) -> void:
    if condition:
        print("PASS: " + description)
    else:
        push_error("FAIL: " + description)
        failures += 1

func key(code: int) -> InputEventKey:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.pressed = true
    return event

func _run() -> void:
    if FileAccess.file_exists(TEST_SAVE):
        DirAccess.remove_absolute(TEST_SAVE)
    game = load("res://Main.tscn").instantiate()
    game.save_file = TEST_SAVE
    root.add_child(game)
    await process_frame
    check(paused and game.overlay.visible, "First launch opens the flight briefing")
    game._resume()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game._process(1.1)
    check(not game.passenger_onboard and game.source_pad != 1, "First passenger waits away from the starting taxi")
    game.taxi.landed_on = game.source_pad
    game.taxi.position = Vector2(game.pads[game.source_pad - 1]["x"], game.pads[game.source_pad - 1]["y"] - 21)
    game._on_landed(game.source_pad)
    game._process(1.1)
    check(game.passenger_onboard, "A waiting rider boards after docking at their pickup pad")
    var wrong: int = 5 if game.destination_pad != 5 else 4
    game._on_landed(wrong)
    check(game.deliveries == 0 and game.passenger_onboard, "Wrong destination cannot complete a fare")
    for index in range(3):
        var destination: int = game.destination_pad
        game.taxi.landed_on = destination
        game.taxi.position = Vector2(game.pads[destination - 1]["x"], game.pads[destination - 1]["y"] - 21.0)
        game._on_landed(destination)
        game._process(1.1)
        if index != 2:
            check(not game.passenger_onboard and game.source_pad != destination, "Delivery requires a new pickup on a different pad")
            game.taxi.landed_on = game.source_pad
            game.taxi.position = Vector2(game.pads[game.source_pad - 1]["x"], game.pads[game.source_pad - 1]["y"] - 21)
            game._on_landed(game.source_pad)
            game._process(1.1)
    check(game.mission_done and game.deliveries == 3 and game.credits > 0, "Three separate pickups and deliveries finish a shift")
    var old_level: int = game.level
    game._unhandled_key_input(key(KEY_N))
    check(game.level == old_level, "N cannot skip star-gate travel")
    game.taxi.landed_on = -1
    game.taxi.position = game.gate_position
    game._process(0.01)
    game.taxi.set_physics_process(false)
    check(game.level == old_level + 1 and not game.mission_done, "Flying through the opened star gate advances the level")
    game.credits = 1000
    game.taxi.landed_on = 2
    game._unhandled_key_input(key(KEY_1))
    check(game.engine_level == 1 and game.credits == 600, "Service upgrade charges credits and updates the taxi")
    game.taxi.fuel = 0.0
    game._unhandled_key_input(key(KEY_T))
    check(game.taxi.landed_on == 2 and game.taxi.fuel == 45.0 and game.credits == 500, "Emergency tow recovers an empty tank")
    game._unhandled_key_input(key(KEY_T))
    check(game.credits == 500, "Emergency tow is limited to one per shift")
    var ship: CharacterBody2D = game.taxi
    var pad: Dictionary = game.pads[0]
    ship.landed_on = -1
    ship.position = Vector2(pad["x"], pad["y"] - 23.0)
    ship.velocity = Vector2(0, 120)
    ship._physics_process(1.0 / 60.0)
    check(ship.landed_on == 1 and ship.velocity == Vector2.ZERO, "Gentle approach settles onto a one-way landing pad")
    ship.landed_on = -1
    ship.position = Vector2(pad["x"], pad["y"] - 23.0)
    ship.velocity = Vector2(300, 300)
    ship._physics_process(1.0 / 60.0)
    check(ship.hull < 100.0 and ship.hull > 0.0 and ship.velocity.y < 0, "Hard landing bounces with partial hull damage")
    var position_before: Vector2 = ship.position
    game._show_pause()
    game._process(2.0)
    check(ship.position == position_before, "Pause preserves flight position")
    game._resume()
    game._save_game()
    game.credits = 0
    game.engine_level = 0
    game._load_game()
    check(game.credits == 500 and game.engine_level == 1, "Career credits and upgrades survive save/load")
    check(game.audio._tones([440.0, 660.0], 0.1).data.size() == 8820, "Sound synthesis produces valid 16-bit PCM")
    for cue in ["pickup", "fare", "complete", "impact", "service", "land", "low"]:
        game.audio.cue(cue)
    await create_timer(1.2).timeout
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(TEST_SAVE):
        DirAccess.remove_absolute(TEST_SAVE)
    print("Integration checks finished: %d failures" % failures)
    quit(0 if failures == 0 else 1)
