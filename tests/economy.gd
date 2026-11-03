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
    game.save_file = "user://frontier_economy_test.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var ship: Node = game.taxi
    ship.fuel = 100
    ship._physics_process(0.05)
    var idle_cost: float = 100 - ship.fuel
    check(idle_cost > 0 and is_equal_approx(idle_cost, 0.005), "Fuel drains at 0.1 per second even while docked")
    ship.position = Vector2(500, 200)
    ship.landed_on = -1
    ship.velocity = Vector2.ZERO
    ship.fuel = 100
    ship._physics_process(0.05)
    check(is_equal_approx(100 - ship.fuel, idle_cost), "Coasting still consumes idle fuel")
    ship.fuel = 100
    Input.action_press("thrust")
    ship._physics_process(0.05)
    Input.action_release("thrust")
    check(100 - ship.fuel > idle_cost * 20, "Thrusters consume additional fuel above the idle rate")
    paused = true
    var paused_fuel: float = ship.fuel
    ship.set_physics_process(true)
    await physics_frame
    await physics_frame
    check(ship.fuel == paused_fuel, "Pause stops all fuel drain")
    ship.set_physics_process(false)
    paused = false
    game.credits = -500
    for delivery in range(3):
        var fare: Dictionary = game.dispatcher.waiting[0]
        game.dispatcher.board(int(fare["source"]))
        game.passenger_onboard = true
        game.destination_pad = int(fare["destination"])
        ship.landed_on = game.destination_pad
        game._on_landed(game.destination_pad)
    check(game.fares_in_level == 3 and not game.mission_done and not game.gate_active, "Three fares cannot unlock the exit below the required balance")
    check(not game.dispatcher.waiting.is_empty(), "Additional fares stay available until the credit target is reached")
    var extra: Dictionary = game.dispatcher.waiting[0]
    game.dispatcher.board(int(extra["source"]))
    game.passenger_onboard = true
    game.destination_pad = int(extra["destination"])
    ship.landed_on = game.destination_pad
    var fuel_before_gate: float = ship.fuel
    game._on_landed(game.destination_pad)
    check(game.gate_active and game.mission_done and game.credits >= game.sector_data["required_balance"], "An extra paid fare unlocks the exit after meeting the balance target")
    check(ship.fuel == fuel_before_gate, "Opening a star gate grants no free departure fuel")
    game.credits = int(game.sector_data["required_balance"]) - 1
    ship.landed_on = -1
    ship.position = game.gate_position
    game._enter_star_gate()
    check(game.level == 0, "Gate entry rechecks the actual cash balance")
    game._process(0)
    check(not game.gate_active and not game.mission_done and not game.dispatcher.waiting.is_empty(), "Spending below the target closes the gate and resumes dispatch")
    game.credits = int(game.sector_data["required_balance"])
    game.mission_done = true
    game._open_star_gate()
    ship.fuel = 27.5
    ship.hull = 63.0
    ship.position = game.gate_position
    ship.landed_on = -1
    game._enter_star_gate()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(game.level == 1 and game.taxi.fuel == 27.5 and game.taxi.hull == 63.0, "Star-gate travel preserves exact fuel and hull in the next sector")
    check(game.sector_data["required_balance"] > 750, "Later sectors require a higher credit balance")
    game._start_level()
    game.taxi.set_physics_process(false)
    check(game.taxi.fuel == game.taxi.fuel_capacity and game.taxi.hull == 100, "Replacement taxis on retries still start repaired and refueled")
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists("user://frontier_economy_test.cfg"):
        DirAccess.remove_absolute("user://frontier_economy_test.cfg")
    print("Fuel and balance progression: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
