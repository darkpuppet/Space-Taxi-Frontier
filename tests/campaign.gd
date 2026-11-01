extends SceneTree
const CAMPAIGN = preload("res://scripts/campaign.gd")
const SECTOR = preload("res://scripts/sector.gd")
var failures: int = 0
var checks: int = 0
var game: Node

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        push_error("FAIL: " + description)
        failures += 1

func _run() -> void:
    game = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_campaign_test.cfg"
    if FileAccess.file_exists(game.save_file):
        DirAccess.remove_absolute(game.save_file)
    root.add_child(game)
    await process_frame
    game._resume()
    game.set_process(false)
    var names: Array = []
    var previous: Dictionary = {}
    var palettes: Array = []
    var layouts: Array = []
    var previous_pads: Array = []
    var seen_types: Array = []
    for level in range(CAMPAIGN.STAGES.size()):
        game.level = level
        game._start_level()
        game.taxi.set_physics_process(false)
        game.sector.set_physics_process(false)
        var config: Dictionary = game.sector_data
        check(not names.has(config["name"]), "Unique name for sector %d" % (level + 1))
        names.append(config["name"])
        if not previous.is_empty():
            check(config["difficulty"] > previous["difficulty"], "Difficulty increases at sector %d" % (level + 1))
            check(config["gravity"] == 300.0, "Normal flight gravity is consistent across levels")
            check(config["aliens"] >= previous["aliens"] and config["holes"] >= previous["holes"], "Hazard counts never decrease")
            check(config["landing_horizontal"] <= previous["landing_horizontal"], "Landing tolerance tightens gradually")
        check(not palettes.has(config["color"]), "Each sector has a unique environment palette")
        palettes.append(config["color"])
        check(not layouts.has(str(game.pads)), "Every sector has a different pad layout")
        layouts.append(str(game.pads))
        var coordinates: Array[Vector2] = []
        var substantial_moves: int = 0
        for pad_index in range(game.pads.size()):
            var pad: Dictionary = game.pads[pad_index]
            var point := Vector2(pad["x"], pad["y"])
            coordinates.append(point)
            check(point.x - float(pad["width"]) * 0.5 > 50 and point.x + float(pad["width"]) * 0.5 < 2350, "Platform stays inside world edges")
            if not previous_pads.is_empty():
                var distance: float = point.distance_to(previous_pads[pad_index])
                check(distance >= 75, "Each platform visibly relocates between levels")
                if distance >= 200:
                    substantial_moves += 1
            if pad_index > 0:
                check(point.x - coordinates[pad_index - 1].x >= 250, "Dock columns leave safe transit corridors")
        if not previous_pads.is_empty():
            check(substantial_moves >= 3, "Most platforms move several hundred pixels in each new level")
        check(CAMPAIGN.pads_for(level) == game.pads, "Authored layout stays stable across retries")
        previous_pads = coordinates
        check(config["introduces"].size() <= 1, "At most one enemy or obstacle family is introduced")
        var new_types: Array = []
        for family in ["planet_count", "asteroids", "gates", "aliens", "wind", "beams", "holes", "drones", "mines", "meteors"]:
            if float(config[family]) > 0 and not seen_types.has(family):
                seen_types.append(family)
                new_types.append(family)
        check(new_types.size() <= 1, "Spawned families match the gradual introduction rule")
        if level == 0:
            check(game.sector.planets.is_empty() and game.sector.navigation_markers().is_empty(), "Tutorial has no planets, enemies, or placed obstacles")
            check(game.sector.field_at(Vector2(1000, 300)) == Vector2.ZERO, "Tutorial has uniform gravity without external gradients")
        previous = config
        check(game.sector.aliens.size() == config["aliens"] and game.sector.holes.size() == config["holes"], "Configured hazards spawned")
        for pad in game.pads:
            check(float(pad["y"]) > 300 and float(pad["y"]) < 1360 and float(pad["width"]) >= 105, "Pad remains reachable with full craft clearance")
        for x in range(50, 2400, 85):
            for y in range(150, 1360, 85):
                var field: Vector2 = game.sector.field_at(Vector2(x, y))
                check(field.is_finite() and field.length() <= 210.01, "Gravity is finite and bounded")
                check(float(config["gravity"]) + field.y < game.taxi.lift, "Stock thrusters can overcome the local gravity")
        check(game.sector.planets.is_empty(), "Planetary gravity objects are removed")
        var holes_backup: Array = game.sector.holes.duplicate(true)
        game.sector.holes.clear()
        check(game.sector.field_at(Vector2(1000, 300)) == Vector2.ZERO, "There are no external fields without black holes")
        game.sector.holes.assign(holes_backup)
        if not game.sector.holes.is_empty():
            var before: Vector2 = game.sector.holes[0]["position"]
            game.sector._physics_process(1.0)
            check(before != game.sector.holes[0]["position"], "Black holes drift over time")
            check(game.sector.field_at(game.sector.holes[0]["position"]).is_finite(), "Gravity is finite at a black hole center")
            check(game.sector.contact_at(game.sector.holes[0]["position"]).get("captured", false), "Black hole core captures the taxi")
        if not game.sector.gates.is_empty():
            var before_gate: Vector2 = game.sector.gates[0]["position"]
            game.sector._physics_process(0.5)
            check(before_gate != game.sector.gates[0]["position"], "Gates move along a visible path")
        if not game.sector.drones.is_empty():
            check(game.sector.contact_at(game.sector.drones[0]["position"]).get("collided", false), "Hunter drones have active collision boundaries")
        if not game.sector.mines.is_empty():
            check(game.sector.contact_at(game.sector.mines[0]["position"]).get("collided", false), "Mines damage at close range")
        if not game.sector.beams.is_empty():
            game.sector.elapsed = 0
            game.sector._physics_process(0)
            check(not game.sector.beams[0]["active"], "Electric beams begin with a safe warning interval")
            game.sector.elapsed = 3.5
            game.sector._physics_process(0)
            check(game.sector.beams[0]["active"], "Electric beams cycle to an active phase")
        if not game.sector.meteors.is_empty():
            var meteor_position: Vector2 = game.sector.meteors[0]["position"]
            game.sector._physics_process(0.5)
            check(meteor_position != game.sector.meteors[0]["position"], "Meteors move across the sector")
        if not game.sector.aliens.is_empty():
            var before: Vector2 = game.sector.aliens[0]["position"]
            game.sector._physics_process(0.5)
            check(before != game.sector.aliens[0]["position"], "Aliens patrol instead of remaining stationary")
        for index in range(3):
            var pickup: int = game.source_pad
            check(pickup != game.last_landed_pad, "Pickup is away from the last arrival terminal")
            game.taxi.landed_on = pickup
            game.taxi.position = Vector2(game.pads[pickup - 1]["x"], game.pads[pickup - 1]["y"] - 21)
            game._on_landed(pickup)
            game._process(1.1)
            check(game.passenger_onboard, "Waiting passenger can board at its source")
            var destination: int = game.destination_pad
            game.taxi.landed_on = destination
            game.taxi.position = Vector2(game.pads[destination - 1]["x"], game.pads[destination - 1]["y"] - 21)
            game._on_landed(destination)
            game._process(1.1)
        check(game.mission_done and game.fares_in_level == 3 and game.gate_active, "Sector %d opens its star gate after three fares" % (level + 1))
        check(not game.sector.resolve_motion(game.gate_position, game.gate_position, Vector2.ZERO).get("collided", false), "Star gate appears clear of solid obstacles")
        print("PASS: Sector %02d / %s / aliens %d / black holes %d" % [level + 1, config["name"], config["aliens"], config["holes"]])
        await process_frame
    check(names.size() == 20, "Campaign includes twenty distinct sectors")
    check(not game.campaign_complete, "Final delivery still requires the last star gate")
    game.taxi.landed_on = -1
    game.taxi.position = game.gate_position
    game._process(0.01)
    check(game.campaign_complete and game.screen_state == "campaign_complete", "Final star gate completes the campaign")
    game._resume()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.level = 19
    game.campaign_complete = true
    var event := InputEventKey.new()
    event.pressed = true
    event.physical_keycode = KEY_N
    game._unhandled_key_input(event)
    check(game.level == 19, "Final sector never advances to a nonexistent level 21")
    game._save_game()
    game.campaign_complete = false
    game._load_game()
    check(game.campaign_complete, "Campaign completion persists")
    # Physics regression cases independent of the campaign's force fields.
    var taxi: CharacterBody2D = game.taxi
    taxi.environment = null
    taxi.engine_level = 0
    taxi.landing_horizontal = 155
    taxi.landing_vertical = 225
    var pad: Dictionary = game.pads[0]
    taxi.landed_on = -1
    taxi.position = Vector2(pad["x"], pad["y"] - 20)
    taxi.velocity = Vector2(0, 40)
    taxi.bounce_timer = 0
    taxi._physics_process(1.0 / 60)
    check(taxi.landed_on == -1, "Cannot snap onto a pad from underneath")
    taxi.position = Vector2(pad["x"] + pad["width"] * 0.5 + 2, pad["y"] - 23)
    taxi.velocity = Vector2(0, 130)
    taxi._physics_process(1.0 / 60)
    check(taxi.landed_on == -1, "Taxi cannot dock when most of its hull hangs past an edge")
    taxi.position = Vector2(400, 100)
    taxi.velocity = Vector2(0, 130)
    taxi.fuel = 100
    Input.action_press("brake")
    taxi._physics_process(1.0 / 60)
    Input.action_release("brake")
    check(taxi.velocity.y > 0 and taxi.velocity.y < 130, "Brake slows descent while allowing touchdown")
    taxi.position = Vector2(400, 100)
    taxi.velocity = Vector2.ZERO
    taxi.fuel = 0
    Input.action_press("thrust")
    Input.action_press("move_right")
    Input.action_press("brake")
    taxi._physics_process(1.0 / 60)
    Input.action_release("thrust")
    Input.action_release("move_right")
    Input.action_release("brake")
    check(not taxi.engine_on and taxi.velocity.y > 0 and taxi.velocity.x == 0, "Empty fuel disables powered controls")
    taxi.hull = 100
    taxi.invulnerable_timer = 0
    taxi._take_damage(12, "ALIEN COLLISION")
    taxi._take_damage(12, "ALIEN COLLISION")
    check(taxi.hull == 88, "Collision invulnerability prevents damage on every physics frame")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    print("Campaign and physics validation: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
