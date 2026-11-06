extends SceneTree
var failures: int = 0
const CAMPAIGN = preload("res://scripts/campaign.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    if not value:
        failures += 1
        push_error("FAIL: " + description)
    else:
        print("PASS: " + description)

func isolate(sector: Node) -> void:
    for family in [sector.planets, sector.aliens, sector.holes, sector.asteroids, sector.gates, sector.drones, sector.mines, sector.meteors, sector.beams]:
        family.clear()

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_collision_test.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var sector: Node = game.sector
    isolate(sector)
    sector.asteroids.append({"position": Vector2(1000, 350), "kind": "asteroid"})
    var hit: Dictionary = sector.resolve_motion(Vector2(850, 350), Vector2(1150, 350), Vector2(300, 0))
    check(hit["collided"] and hit["position"].x < 937 and hit["velocity"].x < 0, "Swept collision stops a fast taxi before an asteroid and rebounds")
    hit = sector.resolve_motion(Vector2(1150, 350), Vector2(850, 350), Vector2(-300, 0))
    check(hit["collided"] and hit["position"].x > 1063 and hit["velocity"].x > 0, "Collision works from the opposite direction")
    hit = sector.resolve_motion(Vector2(1000, 350), Vector2(1001, 350), Vector2.ZERO)
    check(Vector2(hit["position"]).distance_to(Vector2(1000, 350)) > 63, "An existing overlap is pushed completely outside the obstacle")
    hit = sector.resolve_motion(Vector2(1060, 350), Vector2(1060, 360), Vector2(0, 200))
    check(hit["position"].y >= 360 and Vector2(hit["position"]).distance_to(Vector2(1000, 350)) > 63, "An overlapping moving obstacle preserves tangential escape movement")
    var ship: CharacterBody2D = game.taxi
    var impacts: Array[float] = []
    ship.solid_impact.connect(func(speed: float) -> void: impacts.append(speed))
    ship._take_damage(30)
    check(ship.damage_stage() == 1 and ship.smoke_rate() == 0, "Light impact damage scars the hull without emitting smoke")
    ship.invulnerable_timer = 0
    ship._take_damage(20)
    for step in range(20):
        ship._physics_process(0.05)
    var light_smoke: int = ship.damage_smoke.size()
    check(light_smoke > 0 and ship.landed_on == 1, "Damaged taxi emits smoke even while docked")
    var old_cloud: Vector2 = ship.damage_smoke[0]["position"]
    ship.position.x += 100
    ship.facing = -1
    ship._update_damage_smoke(0.01)
    check(Vector2(ship.damage_smoke[0]["position"]).distance_to(old_cloud) < 2, "Smoke stays in world space when the taxi moves and turns")
    ship.position.x -= 100
    ship.invulnerable_timer = 0
    ship._take_damage(40)
    ship.damage_smoke.clear()
    for step in range(20):
        ship._physics_process(0.05)
    check(ship.damage_stage() == 4 and ship.damage_smoke.size() > light_smoke, "Critical damage produces a denser smoke trail")
    for step in range(400):
        ship._update_damage_smoke(0.05)
    check(ship.damage_smoke.size() <= ship.MAX_DAMAGE_SMOKE, "Smoke particle count stays bounded during prolonged damage")
    ship.repair(40)
    check(ship.damage_stage() == 2 and ship.smoke_rate() == 8, "Partial repairs reduce smoke severity")
    ship.repair(100)
    check(ship.damage_stage() == 0 and ship.damage_smoke.is_empty() and ship.smoke_rate() == 0, "Full repair removes hull damage and smoke")
    ship.facing = 1
    ship.invulnerable_timer = 0
    check(ship.impact_damage(300) > ship.impact_damage(100) and ship.impact_damage(100) > ship.impact_damage(20), "Damage rises with impact speed; gentle touches cause no damage")
    ship.landed_on = -1
    ship.position = Vector2(930, 350)
    ship.velocity = Vector2(300, 0)
    ship.invulnerable_timer = 99
    ship._physics_process(0.05)
    check(ship.position.x < 938 and ship.velocity.x < 0 and ship.hull == 100, "Damage protection never lets the taxi pass through a solid")
    check(not impacts.is_empty() and impacts[-1] > 250, "Solid contact emits actual impact speed even during damage protection")
    var audio: Node = game.audio
    audio.impact_cooldown = 0
    audio.impact(25)
    var soft_volume: float = audio.impact_players[0].volume_db
    var soft_pitch: float = audio.impact_players[0].pitch_scale
    for player in audio.impact_players:
        player.stop()
    audio.impact_cooldown = 0
    audio.impact(300)
    check(audio.impact_players[0].volume_db > soft_volume and audio.impact_players[0].pitch_scale < soft_pitch, "Faster collisions produce louder, heavier clunks")
    for family in [sector.aliens, sector.drones, sector.mines, sector.meteors]:
        isolate(sector)
        family.append({"position": Vector2(1000, 350)})
        hit = sector.resolve_motion(Vector2(850, 350), Vector2(1150, 350), Vector2(300, 0))
        check(hit["collided"] and hit["velocity"].x < 0, "Every enemy and moving hazard family has a solid boundary")
    isolate(sector)
    sector.gates.append({"position": Vector2(1000, 350)})
    hit = sector.resolve_motion(Vector2(850, 350), Vector2(1150, 350), Vector2(300, 0))
    check(hit["collided"] and hit["position"].x < 956 and hit["velocity"].x < 0, "Thin gates cannot be tunnelled through")
    hit = sector.resolve_motion(Vector2(1000, 500), Vector2(1000, 200), Vector2(0, -300))
    check(hit["collided"] and hit["velocity"].y > 0, "Gate undersides bounce the taxi")
    isolate(sector)
    sector.beams.append({"position": Vector2(1000, 350), "active": false})
    check(not sector.resolve_motion(Vector2(850, 350), Vector2(1150, 350), Vector2(300, 0))["collided"], "Inactive electric beams allow safe passage")
    sector.beams[0]["active"] = true
    hit = sector.resolve_motion(Vector2(850, 350), Vector2(1150, 350), Vector2(300, 0))
    check(not hit["collided"] and hit["position"] == Vector2(1150, 350) and hit["velocity"] == Vector2(300, 0), "Lit beams allow passage without bouncing or slowing the taxi")
    check(sector.beam_exposure(Vector2(1000, 350), Vector2(1000, 350)) == 1.0, "Stationary hull touching a lit beam remains exposed")
    check(sector.beam_exposure(Vector2(1000, 250), Vector2(1000, 450)) > 0, "Swept beam contact detects a fast crossing with both endpoints outside")
    check(sector.beam_exposure(Vector2(1000, 300), Vector2(1000, 300)) == 0, "Passing above the lit beam does not damage the taxi")
    ship.hull = 100
    ship.invulnerable_timer = 99
    for step in range(20):
        ship._apply_beam_exposure(Vector2(1000, 350), Vector2(1000, 350), 0.05)
    check(is_equal_approx(ship.hull, 76.0), "One second in a lit beam drains 24 hull even during solid-impact protection")
    ship.position = Vector2(1000, 350)
    audio._update_beam_audio(1.0)
    check(audio.beam_player.playing, "Approaching a lit beam plays its electrical hum")
    var near_volume: float = audio.beam_player.volume_db
    ship.position = Vector2(1000, 650)
    audio._update_beam_audio(1.0)
    check(audio.beam_player.playing and audio.beam_player.volume_db < near_volume, "Beam hum becomes quieter farther from the beam")
    sector.beams[0]["active"] = false
    var beam_hull: float = ship.hull
    ship._apply_beam_exposure(Vector2(1000, 350), Vector2(1000, 350), 0.05)
    audio._update_beam_audio(1.0)
    check(ship.hull == beam_hull and not audio.beam_player.playing, "Dark beams cause no damage and stop humming")
    sector.beams[0]["active"] = true
    ship.position = Vector2(900, 350)
    ship.velocity = Vector2(300, 0)
    var prior_impacts: int = impacts.size()
    var prior_hull: float = ship.hull
    ship._physics_process(0.05)
    check(ship.position.x > 900 and ship.velocity.x > 0 and ship.hull < prior_hull, "Real taxi physics moves through lit energy while applying contact damage")
    check(impacts.size() == prior_impacts, "Energy contact never emits a solid clunk")
    ship.position = Vector2(1000, 350)
    audio._update_beam_audio(1.0)
    audio.toggle_mute()
    audio._update_beam_audio(1.0)
    check(not audio.beam_player.playing, "Mute silences beam ambience")
    audio.toggle_mute()
    paused = true
    audio._update_beam_audio(1.0)
    check(not audio.beam_player.playing, "Pause silences beam ambience")
    paused = false
    ship.repair(100)
    isolate(sector)
    var pad: Dictionary = game.pads[0]
    ship.position = Vector2(pad["x"], pad["y"] + 50)
    ship.velocity = Vector2(0, -200)
    ship._physics_process(0.05)
    check(ship.position.y >= float(pad["y"]) + 46 and ship.velocity.y > 0, "Platform undersides are solid and bounce the taxi")
    sector.holes.append({"position": Vector2(900, 300), "radius": 18})
    ship.landed_on = -1
    ship.position = Vector2(866, 300)
    ship.velocity = Vector2(100, 0)
    ship.invulnerable_timer = 99
    ship._physics_process(0.02)
    check(ship.smoke_rate() == 0 and ship.damage_smoke.is_empty(), "Black-hole capture suppresses normal damage smoke")
    check(ship.capture_active and game.lives == 3 and not ship.engine_on, "Black-hole entry starts capture even during damage protection")
    for i in range(12):
        ship._physics_process(0.05)
    check(ship.rotation > 0 and ship.crumple_progress > 0.3 and ship.scale.x > 0.9, "Capture visibly buckles the cab before shrinking it")
    for i in range(45):
        ship._physics_process(0.05)
    check(game.lives == 2 and game.screen_state == "life_lost" and paused, "Completed black-hole animation removes exactly one life")
    check(not game.death_quip.is_empty() and game.overlay_copy.text.contains(game.death_quip), "Black-hole deaths also select a random insult")
    ship._physics_process(0.05)
    check(game.lives == 2, "Finished capture cannot deduct a second life")
    game._resume()
    game.taxi.set_physics_process(false)
    check(game.taxi.scale == Vector2.ONE and game.taxi.rotation == 0 and game.lives == 2, "Retry restores normal taxi shape and keeps two lives")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    print("Solid collisions and black holes: %d failures" % failures)
    quit(0 if failures == 0 else 1)
