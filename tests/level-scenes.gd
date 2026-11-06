extends SceneTree
const CAMPAIGN = preload("res://scripts/campaign.gd")
var checks: int = 0
var failures: int = 0
const PROFILE: String = "user://frontier_level_scenes_test"

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func _run() -> void:
    for index in range(20):
        var packed: PackedScene = load(CAMPAIGN.level_scene_path(index))
        var level: Node = packed.instantiate()
        check(level.sector_index == index, "Level scene selects its campaign sector")
        check(level.background_texture.resource_path.ends_with("level-%02d-v1.png" % (index + 1)), "Scene references existing sector artwork")
        check(level.has_node("Environment") and level.has_node("Pads") and level.has_node("Aurora"), "Scene contains its environment, pad layout and aurora")
        var layout: Array = level.pad_layout()
        check(layout.size() == 5 and layout == CAMPAIGN.pads_for(index), "Campaign layout comes from scene markers")
        check(level.configuration() == CAMPAIGN.sector(index), "Scene defaults preserve campaign difficulty and economy")
        var original: float = layout[0]["x"]
        level.get_node("Pads/Pad01").position.x += 10
        check(level.pad_layout()[0]["x"] == original + 10, "Moving an editor marker changes the gameplay landing position")
        check(CAMPAIGN.pads_for(index)[0]["x"] == original, "Runtime edits cannot modify the packed scene")
        level.get_node("Pads").position.y = 12
        check(level.pad_layout()[0]["y"] == layout[0]["y"] + 12, "Moving the pad group changes all scene-local landing positions")
        level.configuration_overrides = {"gravity": 123.0}
        check(level.configuration()["gravity"] == 123.0, "Scene-local configuration overrides remain editable")
        level.free()
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = PROFILE + ".cfg"
    root.add_child(game)
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var first: Node = game.sector
    game._start_level()
    check(game.sector == first, "Retry reuses the current level scene and resets its hazards")
    game.level = 9
    game._start_level()
    check(game.sector != first and first.is_queued_for_deletion(), "Changing sectors replaces the previous level scene")
    check(game.sector.scene_file_path == CAMPAIGN.level_scene_path(9), "Game loads the requested PackedScene")
    check(game.environment_layers.get_parent() == game.sector, "Current level owns its scenic renderer")
    check(game.taxi.pads == game.sector.pad_layout() and game.sector.docking_pads == game.taxi.pads, "Taxi, hazards and visuals share the scene-authored pads")
    var first_marker: Node2D = game.sector.get_node("Pads/Pad01")
    first_marker.position += Vector2(10, 0)
    game._start_level()
    check(game.taxi.position.x == first_marker.position.x, "Level reset uses edited scene spawn position")
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    await create_timer(0.2).timeout
    # Running a scene directly exercises the same isolated F6 preview path.
    var preview: Node = load(CAMPAIGN.level_scene_path(8)).instantiate()
    root.add_child(preview)
    await process_frame
    await process_frame
    var standalone: Node = current_scene
    check(is_instance_valid(standalone) and standalone.developer_mode and standalone.level == 8, "F6 launches the selected sector in the real game shell")
    check(standalone.screen_state == "playing" and not paused, "F6 preview starts directly in flight")
    var unused_save: String = "user://frontier_scene_preview_must_not_save.cfg"
    standalone.save_file = unused_save
    standalone._save_game()
    check(not FileAccess.file_exists(unused_save), "F6 preview cannot write career progress")
    standalone.audio.shutdown()
    await create_timer(0.2).timeout
    standalone.free()
    await create_timer(0.2).timeout
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix):
            DirAccess.remove_absolute(PROFILE + suffix)
    print("Level scenes: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
