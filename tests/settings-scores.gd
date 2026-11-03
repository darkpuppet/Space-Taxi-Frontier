extends SceneTree
var failures: int = 0
var checks: int = 0
const PROFILE: String = "user://frontier_settings_scores_test"

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func snapshot(filename: String) -> void:
    if DisplayServer.get_name() == "headless": return
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/" + filename + ".png")

func _run() -> void:
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = PROFILE + ".cfg"
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game.settings_button.pressed.emit()
    var dialog: Node = game.menu_dialogs
    check(dialog.visible and not game.overlay.visible and paused and game.screen_state == "menu", "Settings opens from the main menu without starting a shift")
    await snapshot("settings-sound")
    var sliders: Array[Node] = dialog.content.find_children("*", "HSlider", true, false)
    sliders[1].value = 0.35
    check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("FrontierMusic"))), 0.35), "Music slider changes the actual audio bus")
    check(game.audio.engine.bus == "FrontierEffects" and game.audio.radio.player.bus == "FrontierVoices", "Effects and speech have independent mixer buses")
    dialog.show_settings("Game")
    var toggles: Array[Node] = dialog.content.find_children("*", "CheckButton", true, false)
    toggles[1].button_pressed = false
    toggles[2].button_pressed = false
    check(not game.preferences.values["camera_shake"] and not game.preferences.values["ticker"], "Game toggles control camera shake and the title ticker independently")
    var name_field: LineEdit = dialog.content.find_children("*", "LineEdit", true, false)[0]
    name_field.text = "ACE"
    name_field.text_changed.emit("ACE")
    dialog.show_settings("Controls")
    dialog.content.get_child(1).pressed.emit()
    var key := InputEventKey.new()
    key.pressed = true
    key.physical_keycode = KEY_J
    dialog._input(key)
    check(game.preferences.keys["move_left"] == KEY_J and InputMap.action_has_event("move_left", key), "Rebinding captures a new physical key in the actual input map")
    var old_key := InputEventKey.new()
    old_key.physical_keycode = KEY_A
    check(not InputMap.action_has_event("move_left", old_key), "Rebinding removes the old keyboard key")
    check(not game.preferences.bind_key("move_left", KEY_M) and not game.preferences.bind_key("move_left", KEY_D), "Reserved and duplicate key bindings are rejected")
    game.preferences.set_value("deadzone", 0.3)
    game.preferences.apply_controls()
    check(is_equal_approx(InputMap.action_get_deadzone("thrust"), 0.3), "Controller dead-zone preference changes input handling")
    await snapshot("settings-controls")
    var saved = preload("res://scripts/preferences.gd").new()
    saved.path = PROFILE + "_settings.cfg"
    saved.load_settings()
    check(saved.keys["move_left"] == KEY_J and saved.values["pilot"] == "ACE" and is_equal_approx(saved.values["music"], 0.35), "Pilot, control, and volume preferences survive a reload")
    dialog.close()
    check(game.overlay.visible and not dialog.visible and paused and not game.title_ticker.visible, "Back restores the main menu and respects the ticker preference")
    game.preferences.reset_controls()
    game._new_game()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game._show_pause()
    game.settings_button.pressed.emit()
    dialog.close()
    check(game.screen_state == "paused" and paused, "Closing settings from Pause does not resume gameplay")
    for index in range(12): game.high_scores.record("Pilot %d" % index, index * 100, index + 1, index, false)
    check(game.high_scores.entries.size() == 10 and game.high_scores.entries[0]["credits"] == 1100, "High scores are ranked and limited to ten entries")
    var scores = preload("res://scripts/high_scores.gd").new()
    scores.path = PROFILE + "_scores.cfg"
    scores.load_scores()
    check(scores.entries == game.high_scores.entries, "The high-score table survives reload")
    check(not game.high_scores.qualifies(200, 1, 0), "A run below the tenth-place score does not qualify")
    var tenth: Dictionary = game.high_scores.entries[-1]
    check(not game.high_scores.qualifies(tenth["credits"], tenth["level"], tenth["fares"]), "An exact tie does not displace an existing tenth-place score")
    game._resume()
    game.credits = 9999
    game.lives = 1
    game._lose_life()
    check(dialog.visible and dialog.tab == "Score entry" and dialog.score_name.text == "ACE", "A qualifying Game Over prompts for a name, prefilled with the previous pilot")
    check(not game.score_recorded and game.high_scores.entries[0]["credits"] == 1100, "Qualifying scores wait for name confirmation before saving")
    await snapshot("high-score-name")
    dialog.score_name.text = "   "
    dialog._save_score()
    check(not game.pending_high_score.is_empty() and not game.score_recorded, "Blank names cannot submit a leaderboard entry")
    dialog.score_name.text = "  Nova Rider  "
    dialog.score_name.text_submitted.emit(dialog.score_name.text)
    check(game.score_recorded and game.high_scores.entries[0]["pilot"] == "Nova Rider" and game.high_scores.entries[0]["credits"] == 9999, "Enter saves the trimmed name and final score")
    check(dialog.tab == "Scores" and game.preferences.values["pilot"] == "Nova Rider", "Saving shows the leaderboard and remembers the new pilot name")
    var recorded: Array = game.high_scores.entries.duplicate(true)
    game._record_high_score()
    check(game.high_scores.entries == recorded, "A finished run cannot enter the table twice")
    game.scores_button.pressed.emit()
    check(dialog.visible and dialog.tab == "Scores", "High-score table is accessible from Game Over")
    var board: Control = dialog.score_board
    var saved_entries: Array = game.high_scores.entries.duplicate(true)
    check(board.cells.size() == 420 and not board.settled(), "Leaderboard opens as a ten-row animated split-flap board")
    board._process(0.4)
    check(board.elapsed > 0 and paused, "Split-flap animation advances while the game is paused")
    var changing: bool = false
    for cell in board.cells:
        if board.cell_state(cell)["glyph"] != cell["target"]:
            changing = true
    check(changing, "Characters cycle through intermediate values before reaching the score")
    await snapshot("high-scores-flipping")
    board._process(10.0)
    var correct: bool = true
    for cell in board.cells:
        correct = correct and board.cell_state(cell)["glyph"] == cell["target"] and board.cell_state(cell)["scale"] == 1.0
    check(board.settled() and correct, "Every flap settles on its exact target letter or digit")
    check(game.high_scores.entries == saved_entries, "Split-flap formatting and animation do not modify saved scores")
    await snapshot("high-scores")
    dialog.close()
    game.developer_mode = true
    game.score_recorded = false
    game.credits = 999999
    game._record_high_score()
    check(game.high_scores.entries == recorded, "Developer sessions cannot submit high scores")
    game.developer_mode = false
    game._new_game()
    game.taxi.set_physics_process(false)
    game.credits = 0
    game.lives = 1
    game._lose_life()
    check(not dialog.visible and game.pending_high_score.is_empty() and game.high_scores.entries == recorded, "Nonqualifying runs show Game Over without a name prompt")
    game._new_game()
    game.taxi.set_physics_process(false)
    game.credits = 20000
    game.lives = 1
    game._lose_life()
    dialog.close()
    check(game.pending_high_score.is_empty() and game.score_recorded and game.high_scores.entries == recorded, "Skipping a qualifying entry returns to Game Over without adding a score")
    game._new_game()
    game.level = 19
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game.credits = int(game.sector_data["required_balance"])
    game.fares_in_level = 3
    game.mission_done = true
    game.gate_active = true
    game.gate_position = Vector2(500, 200)
    game.taxi.position = game.gate_position
    game.taxi.landed_on = -1
    game._enter_star_gate()
    check(game.campaign_complete and dialog.tab == "Score entry" and game.pending_high_score["complete"], "Campaign completion also prompts for a qualifying score")
    dialog.score_name.text = "Galaxy Ace"
    dialog._save_score()
    check(game.high_scores.entries[0]["complete"] and game.high_scores.entries[0]["pilot"] == "Galaxy Ace", "Confirmed campaign entries retain their completion status")
    scores.load_scores()
    check(scores.entries[0]["pilot"] == "Galaxy Ace", "The entered leaderboard name survives reloading the score file")
    game.preferences.reset_controls()
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    await create_timer(0.2).timeout
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
    print("Settings and high scores: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
