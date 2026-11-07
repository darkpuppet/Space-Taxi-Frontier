extends SceneTree
var failures: int = 0

func check(value: bool, label: String) -> void:
    if not value:
        failures += 1
        push_error("FAIL: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_rain_test.cfg"
    root.add_child(game)
    await process_frame
    game._new_game()
    game.level = 5
    game._start_level()
    game._resume()
    var environment: Node = game.environment_layers
    check(environment.rain_layers.size() == 2, "Level 6 creates two rain depths")
    var middle: Node2D = environment.rain_layers[0]
    var front: Node2D = environment.rain_layers[1]
    check(middle.z_index > environment.window_frame.z_index and middle.z_index < environment.near_landscape.z_index, "Middle rain is occluded by near scenery")
    check(front.z_index > environment.buildings.z_index, "Foreground rain crosses front scenery")
    var before: float = front.elapsed
    await create_timer(0.1).timeout
    check(front.elapsed > before, "Rain falls during gameplay")
    game._show_pause()
    before = front.elapsed
    await create_timer(0.1).timeout
    check(front.elapsed == before, "Rain freezes during pause")
    game._resume()
    game._start_level()
    check(game.environment_layers.rain_layers[1] == front, "Retry reuses rain nodes")
    game.level = 6
    game._start_level()
    check(game.environment_layers.rain_layers.is_empty(), "Other levels have no rain")
    game.audio.shutdown()
    game.free()
    paused = false
    await create_timer(0.2).timeout
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        var path: String = "user://frontier_rain_test" + suffix
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
    print("Level 6 rain: 7 checks, %d failures" % failures)
    quit(1 if failures else 0)
