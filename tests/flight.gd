extends SceneTree
## Actual inputs and physics: chooses riders, refuels, repairs, and enters gates.
const WORLD = preload("res://scripts/world.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func key(code: int) -> InputEventKey:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.pressed = true
    return event

func release_controls() -> void:
    for action in ["thrust", "move_left", "move_right", "brake"]:
        Input.action_release(action)

func steer(error: float, cap: float = 0.50) -> void:
    Input.action_release("move_left")
    Input.action_release("move_right")
    if absf(error) > 2:
        Input.action_press("move_right" if error > 0 else "move_left", clampf(absf(error) * 2.0 / 330, 0.06, cap))

func clear_line(game: Node, start: Vector2, finish: Vector2) -> bool:
    var collision: Dictionary = game.sector.resolve_motion(start, finish, Vector2.ZERO)
    if collision.get("collided", false) or collision.get("captured", false):
        return false
    for pad in game.pads:
        var center := Vector2(float(pad["x"]), float(pad["y"]) + 12.5)
        if not game.sector._box_hit(start, finish, center, Vector2(float(pad["width"]) * 0.5 + 37, 37)).is_empty():
            return false
    for hole in game.sector.holes:
        var half := Vector2(float(hole["drift"]) + 80, 110)
        if not game.sector._box_hit(start, finish, hole["home"], half).is_empty():
            return false
    return true

func route(game: Node, goal: Vector2) -> PackedVector2Array:
    var navigation: Dictionary = game._gate_navigation()
    var grid: AStarGrid2D = navigation["grid"]
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    var end: Vector2i = navigation["start"]
    var best: float = INF
    for y in range(grid.region.size.y):
        for x in range(grid.region.size.x):
            var id := Vector2i(x, y)
            if grid.is_point_solid(id):
                continue
            var distance: float = grid.get_point_position(id).distance_squared_to(goal)
            if distance < best:
                best = distance
                end = id
    var points: PackedVector2Array = grid.get_point_path(navigation["start"], end)
    points.append(goal)
    return points

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_flight_test.cfg"
    if FileAccess.file_exists(game.save_file):
        DirAccess.remove_absolute(game.save_file)
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    var trace: int = -1
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--trace-level="):
            trace = argument.get_slice("=", 1).to_int() - 1
    for level in ([trace] if trace >= 0 else range(20)):
        release_controls()
        paused = false
        game.screen_state = "playing"
        game.lives = 3
        game.level = level
        game.engine_level = 0
        game.stabilizer_level = 0
        game.tank_level = mini(2, int(level / 8))
        if trace > 0:
            game.credits = int(preload("res://scripts/campaign.gd").sector(level - 1)["required_balance"])
        game.gate_rng.seed = 1701 + level * 97
        game._start_level()
        game.abductions.rng.seed = 7821 + level * 97
        game.abductions.countdown = game.abductions.rng.randf_range(18.0, 28.0)
        game.taxi.set_physics_process(false)
        game.sector.set_physics_process(false)
        var ship: CharacterBody2D = game.taxi
        var target_id: int = -1
        var chosen_fare: int = -1
        var refueling: bool = false
        var fuel_stop_progress: int = -1
        var points := PackedVector2Array()
        var waypoint: int = 0
        var path_age: float = 99
        var cleared: bool = false
        var elapsed: float = 0
        for step in range(36000):
            var dt: float = 1.0 / 60
            elapsed += dt
            path_age += dt
            if game.screen_state == "life_lost":
                print("RETRY: Sector %02d / %d lives remaining" % [level + 1, game.lives])
                game._resume()
                ship = game.taxi
                ship.set_physics_process(false)
                game.sector.set_physics_process(false)
                target_id = -1
                chosen_fare = -1
                refueling = false
                fuel_stop_progress = -1
            if game.screen_state == "game_over":
                break
            if ship.input_locked:
                release_controls()
                game._process(dt)
                target_id = -1
                continue
            var mission_progress: int = game.fares_in_level * 2 + (1 if game.passenger_onboard else 0)
            if refueling and ship.landed_on == 2:
                if ship.fuel < ship.fuel_capacity - 1 and game.credits > 0:
                    release_controls()
                    ship._physics_process(dt)
                    game._process(dt)
                    continue
                refueling = false
                fuel_stop_progress = mission_progress
                target_id = -1
                if ship.hull < 65 and game.credits >= 75:
                    game._unhandled_key_input(key(KEY_4))
            # After a fuel stop, finish the current pickup/dropoff before using
            # the normal reserve threshold again; otherwise long routes loop.
            if ship.fuel < 45 and ship.landed_on != 2 and (mission_progress != fuel_stop_progress or ship.fuel < 15):
                refueling = true
            var selected: Dictionary = {}
            if not game.passenger_onboard and not game.gate_active:
                for fare in game.dispatcher.waiting:
                    if int(fare["id"]) == chosen_fare:
                        selected = fare
                if selected.is_empty():
                    selected = game.dispatcher.suggested(ship.position)
                    chosen_fare = int(selected.get("id", -1))
            else:
                chosen_fare = -1
            var next_id: int = 2 if refueling else (6 if game.gate_active else (game.destination_pad if game.passenger_onboard else int(selected.get("source", 0))))
            if next_id <= 0 or (next_id != 6 and ship.landed_on == next_id and not game.passenger_onboard and not refueling):
                release_controls()
            else:
                var final: Vector2 = game.gate_position if next_id == 6 else Vector2(game.pads[next_id - 1]["x"], game.pads[next_id - 1]["y"] - 21)
                if next_id != 6 and not game.passenger_onboard and not refueling:
                    final.x -= 20 # Land beside the rider, leaving room for the boarding walk.
                var staging: Vector2 = final if next_id == 6 else final - Vector2(0, 90)
                if next_id != target_id or path_age > 2.0:
                    points = route(game, staging)
                    waypoint = 0
                    path_age = 0
                    target_id = next_id
                while waypoint < points.size() - 1 and ship.position.distance_to(points[waypoint]) < 26:
                    waypoint += 1
                for lookahead in range(mini(points.size() - 1, waypoint + 8), waypoint, -1):
                    if (absf(ship.position.x - points[lookahead].x) < 32 or absf(ship.position.y - points[lookahead].y) < 32) and clear_line(game, ship.position, points[lookahead]):
                        waypoint = lookahead
                        break
                var target: Vector2 = points[waypoint]
                var landing: bool = next_id != 6 and absf(ship.position.x - final.x) < 30 and ship.position.y > staging.y - 25 and ship.position.y <= final.y + 3
                if landing:
                    target = final + Vector2(0, 5)
                # Use slower approaches in sectors with gravitational hazards.
                var cautious: bool = not game.sector.holes.is_empty()
                steer(target.x - ship.position.x, 0.50 if cautious else 0.65)
                var desired: float = clampf((target.y - ship.position.y) * (1.5 if cautious else 1.8), -120 if cautious else -180, 85 if cautious else 130)
                if landing:
                    desired = 48
                if ship.landed_on != -1 or ship.velocity.y > desired:
                    Input.action_press("thrust")
                else:
                    Input.action_release("thrust")
            game.sector._physics_process(dt)
            ship._physics_process(dt)
            game._process(dt)
            if game.level != level or game.campaign_complete:
                cleared = true
                break
            if ship.fuel < 10 and game.tow_available:
                game._unhandled_key_input(key(KEY_T))
                target_id = -1
                refueling = false
            if trace >= 0 and step % 120 == 0:
                print("TRACE %.1fs / target %d / fares %d / pos %s / fuel %.1f / hull %.0f" % [elapsed, target_id, game.fares_in_level, ship.position, ship.fuel, ship.hull])
            if ship.fuel <= 0 and ship.position.y > WORLD.FLOOR - 40:
                break
            if step % 180 == 0:
                await process_frame
        release_controls()
        if cleared:
            print("PASS: Real flight sector %02d / %.1fs / fuel %.1f / hull %.0f" % [level + 1, elapsed, ship.fuel, ship.hull])
        else:
            failures += 1
            push_error("FAIL: Real flight sector %02d / fares %d / fuel %.1f / hull %.0f / pos %s" % [level + 1, game.fares_in_level, ship.fuel, ship.hull, ship.position])
        await process_frame
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    print("Real flight campaign: %d failures" % failures)
    quit(0 if failures == 0 else 1)
