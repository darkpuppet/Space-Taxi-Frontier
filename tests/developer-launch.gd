extends SceneTree
const MAIN = preload("res://scripts/main.gd")
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
    for level in [1, 9, 20]:
        check(MAIN.developer_level_from_args(PackedStringArray(["--dev-level=%d" % level])) == level, "Developer levels use one-based campaign numbers")
    for argument in ["--dev-level=0", "--dev-level=21", "--dev-level=-1", "--dev-level=nope", "--dev-level=3.5", "--dev-level=", "--trace-level=9"]:
        check(MAIN.developer_level_from_args(PackedStringArray([argument])) == 0, "Invalid or unrelated arguments cannot change the starting level")
    check(MAIN.developer_level_from_args(PackedStringArray()) == 0, "Ordinary launch has no developer override")
    var target: int = MAIN.developer_level_from_args(OS.get_cmdline_user_args())
    check(target > 0, "This test was launched with an actual developer level argument")
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_developer_launch_test.cfg"
    var fixture := ConfigFile.new()
    fixture.set_value("career", "credits", 98765)
    fixture.set_value("career", "level", 17)
    fixture.save(game.save_file)
    var original: String = FileAccess.get_file_as_string(game.save_file)
    root.add_child(game)
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    await process_frame
    check(game.developer_mode and game.level == target - 1, "Actual launch argument opens the requested level")
    check(game.screen_state == "playing" and not paused and not game.overlay.visible, "Developer launch begins flight immediately")
    check(game.lives == 3 and game.credits == 0 and game.taxi.hull == 100, "Developer launch uses a fresh taxi and ignores career progress")
    check(game.pads == game.CAMPAIGN.pads_for(target - 1), "Developer launch loads the real authored layout")
    check(game.sector.config["index"] == target - 1, "Developer launch loads the requested hazards")
    game.credits = 55
    game._save_game()
    check(FileAccess.get_file_as_string(game.save_file) == original, "Developer test actions cannot overwrite career saves")
    game._load_game()
    check(game.credits == 55, "Developer session cannot import saved career upgrades")
    game._return_to_menu()
    check(game.level == 0 and paused and game.screen_state == "menu", "Returning to menu still resets the run to Level 1")
    game._new_game()
    check(game.level == 0 and game.lives == 3, "New Game still starts at Level 1")
    check(FileAccess.get_file_as_string(game.save_file) == original, "Menu and New Game remain isolated from career saves")
    game.audio.shutdown()
    await create_timer(0.5).timeout
    var fixture_path: String = game.save_file
    game.free()
    await create_timer(0.2).timeout
    DirAccess.remove_absolute(fixture_path)
    print("Developer Level %02d: %d checks, %d failures" % [target, checks, failures])
    quit(0 if failures == 0 else 1)
