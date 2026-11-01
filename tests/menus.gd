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
    var picker = preload("res://scripts/death_quips.gd").new()
    picker.rng.seed = 77219
    var previous: String = ""
    for cycle in range(2):
        var heard: Dictionary = {}
        for index in range(picker.LIBRARY.phrases.size()):
            var line: String = picker.choose()
            check(picker.LIBRARY.phrases.has(line) and line != previous, "Death lines come from the editable library without consecutive repeats")
            heard[line] = true
            previous = line
        check(heard.size() == picker.LIBRARY.phrases.size(), "Each shuffle uses every death insult")
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
    check(game.title_backdrop.visible and game.title_backdrop.texture != null, "Title menu displays the orbital taxi stand bitmap")
    check(game.title_ticker.visible and not game.title_ticker.messages.is_empty(), "Title screen shows the editable space-taxi dispatch wire")
    var ticker_offset: float = game.title_ticker.offset
    game.title_ticker._process(1.0)
    check(game.title_ticker.offset > ticker_offset and paused, "Dispatch ticker scrolls while the title menu pauses gameplay")
    var ticker: Control = game.title_ticker
    var current: int = ticker.message_index
    ticker.offset = ticker.size.x + ticker.widths[current] - ticker.BADGE_WIDTH - 20
    ticker._process(0.1)
    check(ticker.message_index == current and ticker.gap_remaining == 0, "Next message waits while the current message is still visible")
    ticker._process(1.0)
    check(ticker.message_index == current and ticker.message_right_edge() < ticker.BADGE_WIDTH and ticker.gap_remaining > 0, "A blank gap begins only after the complete message exits")
    ticker._process(0.3)
    check(ticker.message_index == current and ticker.gap_remaining > 0, "No new message appears during the gap")
    ticker._process(0.4)
    check(ticker.message_index == (current + 1) % ticker.messages.size() and ticker.offset == 0, "Next message starts at the right edge after the gap")
    ticker.message_index = ticker.messages.size() - 1
    ticker.offset = ticker.size.x + ticker.widths[-1]
    ticker._process(0.01)
    ticker._process(1.0)
    check(ticker.message_index == 0 and ticker.offset == 0, "Single-message ticker cycles back to the first message")
    check(not ticker.dot_patterns[0].is_empty(), "Ticker renders messages as LED dot-matrix glyphs")
    ticker.offset = 650
    if DisplayServer.get_name() != "headless":
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://tests/title-screen.png")
    check(game.exit_button.visible and not game.menu_button.visible, "Main menu offers New Game and Exit")
    game.resume_button.pressed.emit()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    check(not paused and game.level == 0 and game.lives == 3 and game.credits == 0, "New Game starts Level 1 with three lives and a fresh run")
    check(not game.title_backdrop.visible, "Starting a shift hides the title artwork")
    check(not game.title_ticker.visible, "Dispatch ticker hides during gameplay")
    game.level = 5
    game.credits = 1000
    game.engine_level = 2
    game._start_level()
    game.taxi.set_physics_process(false)
    game.taxi.hull = 0
    game._process(0.02)
    check(game.explosion_active and game.lives == 3 and not paused and not game.overlay.visible, "Destruction plays an explosion before the life-loss screen")
    var crash_quip: String = game.death_quip
    check(not crash_quip.is_empty() and game.banner.text.contains(crash_quip), "Taxi destruction immediately displays a random insult")
    check(not game.taxi.visible and game.taxi.input_locked and not game.taxi.engine_on, "Destroyed taxi disappears and cannot fly during the explosion")
    check(game.taxi.smoke_rate() == 0, "Destroyed taxi stops damage-smoke emission during the explosion")
    check(game.explosion.sparks.size() == 64 and game.explosion.debris.size() == 8, "Explosion emits sparks and eight pieces of the taxi sprite")
    game._process(0.18)
    check(game.camera.offset.length() > 0, "Blast shakes the camera briefly")
    var blast_age: float = game.explosion.age
    game._show_pause()
    check(not game.title_backdrop.visible and game.overlay.offset_right == 0, "Pause restores the centered gameplay overlay")
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
    check(game.death_quip == crash_quip and game.overlay_copy.text.contains(crash_quip), "Retry screen retains the same insult chosen for the explosion")
    check(not game.explosion_active and game.camera.offset == Vector2.ZERO, "Explosion ends and clears camera shake")
    game._process(1)
    game._lose_life()
    check(game.lives == 2, "A single destruction cannot deduct multiple lives")
    game.resume_button.pressed.emit()
    game.taxi.set_physics_process(false)
    check(game.level == 5 and game.lives == 2 and game.taxi.hull == 100 and game.engine_level == 2 and game.credits == 1000, "Retry preserves sector and upgrades, repairs taxi, and keeps remaining lives")
    check(game.death_quip.is_empty(), "Retry clears the previous death message")
    check(game.taxi.visible and not game.explosion_active and game.explosion == null, "Retry clears the old explosion and restores the taxi sprite")
    game._lose_life("RETRY REQUESTED")
    check(game.death_quip.is_empty(), "Voluntary restart does not invent a death insult")
    game._resume()
    game.taxi.set_physics_process(false)
    game._lose_life()
    check(game.lives == 0 and game.screen_state == "game_over" and paused, "Third loss ends the run")
    check(not game.death_quip.is_empty() and game.overlay_copy.text.contains(game.death_quip), "Final life loss also displays an insult on Game Over")
    if DisplayServer.get_name() != "headless":
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://tests/death-insult.png")
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
    check(game.title_backdrop.visible, "Returning to the title menu restores the taxi stand")
    check(game.title_ticker.visible, "Returning to the title menu restores the ticker")
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
