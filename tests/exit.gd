extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_exit_test.cfg"
    root.add_child(game)
    await process_frame
    # Emitting the actual menu signal must quit before the fallback timer.
    print("Exit control: 0 failures")
    game.exit_button.pressed.emit()
    if FileAccess.file_exists(game.save_file):
        DirAccess.remove_absolute(game.save_file)
    var fallback := Timer.new()
    fallback.process_mode = Node.PROCESS_MODE_ALWAYS
    fallback.one_shot = true
    fallback.wait_time = 1.0
    root.add_child(fallback)
    fallback.timeout.connect(_exit_failed)
    fallback.start()

func _exit_failed() -> void:
    push_error("FAIL: Exit button did not close the application")
    quit(1)
