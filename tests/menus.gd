extends SceneTree
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    if not value:
        failures += 1
        push_error("FAIL: " + description)
    else:
        print("PASS: " + description)

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_menu_test.cfg"
    var fixture := ConfigFile.new()
    fixture.set_value("career", "level", 17)
    fixture.set_value("career", "lives", 1)
    fixture.set_value("career", "credits", 999)
    fixture.save(game.save_file)
    root.add_child(game)
    await process_frame
    check(paused and game.screen_state == "menu" and game.level == 0, "Startup shows Level 1 main menu even with a late-game save")
    check(game.exit_button.visible and not game.menu_button.visible, "Main menu offers New Game and Exit")
    game.resume_button.pressed.emit()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    check(not paused and game.level == 0 and game.lives == 3 and game.credits == 0, "New Game starts Level 1 with three lives and a fresh run")
    game.level = 5
    game.credits = 1000
    game.engine_level = 2
    game._start_level()
    game.taxi.set_physics_process(false)
    game.taxi.hull = 0
    game._process(0.02)
    check(game.explosion_active and game.lives == 3 and not paused and not game.overlay.visible, "Destruction plays an explosion before the life-loss screen")
    check(not game.taxi.visible and game.taxi.input_locked and not game.taxi.engine_on, "Destroyed taxi disappears and cannot fly during the explosion")
    check(game.taxi.smoke_rate() == 0, "Destroyed taxi stops damage-smoke emission during the explosion")
    check(game.explosion.sparks.size() == 64 and game.explosion.debris.size() == 8, "Explosion emits sparks and eight pieces of the taxi sprite")
    game._process(0.18)
    check(game.camera.offset.length() > 0, "Blast shakes the camera briefly")
    var blast_age: float = game.explosion.age
    game._show_pause()
    game._process(1)
    check(game.explosion.age == blast_age and game.lives == 3, "Pause freezes the explosion and life-loss timing")
    game._resume()
    var blocked_action := InputEventKey.new()
    blocked_action.pressed = true
    blocked_action.physical_keycode = KEY_T
    game._unhandled_key_input(blocked_action)
    check(game.tow_available and game.taxi.hull == 0, "Emergency tow cannot revive an exploding taxi")
    game._lose_life()
    check(game.lives == 3, "An explosion cannot deduct a life before its animation finishes")
    game._process(1.3)
    check(game.lives == 2 and paused and game.screen_state == "life_lost", "Completed explosion costs one life and opens retry screen")
    check(not game.explosion_active and game.camera.offset == Vector2.ZERO, "Explosion ends and clears camera shake")
    game._process(1)
    game._lose_life()
    check(game.lives == 2, "A single destruction cannot deduct multiple lives")
    game.resume_button.pressed.emit()
    game.taxi.set_physics_process(false)
    check(game.level == 5 and game.lives == 2 and game.taxi.hull == 100 and game.engine_level == 2 and game.credits == 1000, "Retry preserves sector and upgrades, repairs taxi, and keeps remaining lives")
    check(game.taxi.visible and not game.explosion_active and game.explosion == null, "Retry clears the old explosion and restores the taxi sprite")
    game._lose_life()
    game._resume()
    game.taxi.set_physics_process(false)
    game._lose_life()
    check(game.lives == 0 and game.screen_state == "game_over" and paused, "Third loss ends the run")
    check(game.menu_button.visible and game.exit_button.visible, "Game Over offers New Game, Main Menu, and Exit")
    game.resume_button.pressed.emit()
    game.taxi.set_physics_process(false)
    check(game.level == 0 and game.lives == 3 and not paused, "New Game after Game Over resets to Level 1 and three lives")
    game.level = 8
    game._start_level()
    game.taxi.set_physics_process(false)
    game._show_pause()
    check(game.menu_button.visible and game.exit_button.visible, "Pause offers Resume, Main Menu, and Exit")
    game.menu_button.pressed.emit()
    check(game.screen_state == "menu" and paused and game.level == 0, "Return to Main Menu resets the run to Level 1")
    game.resume_button.pressed.emit()
    game.taxi.set_physics_process(false)
    check(game.lives == 3 and game.level == 0 and not paused, "Starting again from the menu gives three fresh lives")
    check(game.exit_button.pressed.is_connected(game._exit_game), "Exit button is wired to application quit")
    var test_save: String = game.save_file
    game.audio.shutdown()
    await create_timer(0.5).timeout
    game.free()
    await create_timer(0.2).timeout
    DirAccess.remove_absolute(test_save)
    print("Lives and menus: %d failures" % failures)
    quit(0 if failures == 0 else 1)
