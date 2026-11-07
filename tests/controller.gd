extends SceneTree
var failures: int = 0
var checks: int = 0
const PROFILE: String = "user://frontier_controller_test"

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func button(index: int, pressed: bool, device: int = 0) -> void:
    var event := InputEventJoypadButton.new()
    event.device = device
    event.button_index = index
    event.pressed = pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func tap(index: int) -> void:
    button(index, true)
    await process_frame
    button(index, false)
    await process_frame

func axis(index: int, value: float, device: int = 0) -> void:
    var event := InputEventJoypadMotion.new()
    event.device = device
    event.axis = index
    event.axis_value = value
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func _run() -> void:
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = PROFILE + ".cfg"
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.taxi.set_physics_process(false)
    await tap(JOY_BUTTON_START)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(game.screen_state == "playing" and not paused, "Start begins a new game from the title menu")
    var retry_key := InputEventKey.new()
    retry_key.physical_keycode = KEY_R
    retry_key.pressed = true
    game._unhandled_key_input(retry_key)
    check(paused and game.menu_dialogs.visible and game.menu_dialogs.tab == "Retry" and game.lives == 3, "R pauses and asks before spending a life")
    retry_key.echo = true
    game._unhandled_key_input(retry_key)
    check(game.lives == 3, "Holding R cannot spend lives through the confirmation")
    retry_key.echo = false
    retry_key.physical_keycode = KEY_ESCAPE
    game._unhandled_key_input(retry_key)
    check(not game.menu_dialogs.visible and paused and game.lives == 3, "Escape cancels keyboard retry without spending a life")
    game._resume()
    check(game.controller_active and game.controls.text.contains("START"), "Controller input switches the flight prompts")
    game.taxi.landed_on = -1
    game.taxi.position = Vector2(500, 200)
    game.taxi.velocity = Vector2.ZERO
    axis(JOY_AXIS_LEFT_X, 0.8, 1)
    game.taxi._physics_process(0.05)
    check(game.taxi.velocity.x > 0 and Input.get_axis("move_left", "move_right") > 0, "Left stick steers the taxi through the input map")
    axis(JOY_AXIS_LEFT_X, 0, 1)
    button(JOY_BUTTON_DPAD_LEFT, true, 1)
    check(Input.is_action_pressed("move_left"), "D-pad provides digital steering")
    button(JOY_BUTTON_DPAD_LEFT, false, 1)
    axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
    game.taxi._physics_process(0.05)
    check(game.taxi.engine_on, "Right trigger fires the lift thrusters")
    axis(JOY_AXIS_TRIGGER_RIGHT, 0)
    axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
    check(Input.is_action_pressed("brake"), "Left trigger activates braking")
    axis(JOY_AXIS_TRIGGER_LEFT, 0)
    await tap(JOY_BUTTON_START)
    check(paused and game.screen_state == "paused", "Start pauses flight")
    game.resume_button.grab_focus()
    await tap(JOY_BUTTON_DPAD_DOWN)
    check(root.gui_get_focus_owner() != game.resume_button, "D-pad navigates between actual menu controls")
    game.settings_button.grab_focus()
    await tap(JOY_BUTTON_A)
    check(game.menu_dialogs.visible and game.menu_dialogs.tab == "Sound", "A activates the focused Settings button")
    await tap(JOY_BUTTON_B)
    check(not game.menu_dialogs.visible and paused, "B closes settings without resuming flight")
    await tap(JOY_BUTTON_START)
    check(not paused, "Start resumes from Pause")
    game.credits = 1000
    game.taxi.fuel = 10
    await tap(JOY_BUTTON_Y)
    check(game.tow_truck.state == "approach" and game.taxi.input_locked and game.credits == 700, "Y requests the animated 300-credit emergency tow")
    for step in range(2400):
        game.tow_truck.advance(1.0 / 60)
        if game.tow_truck.state == "depart":
            break
    check(game.taxi.landed_on == 2 and game.taxi.fuel == 55, "Tow delivers the taxi before the workshop can open")
    await tap(JOY_BUTTON_X)
    check(paused and game.menu_dialogs.tab == "Workshop", "X at PAD 02 opens the controller workshop")
    check(game.upgrades.text.contains("PRESS X"), "Fuel-pad prompt names the controller shop button")
    for shop_button in game.menu_dialogs.workshop_buttons:
        check(shop_button.icon != null and shop_button.text.contains("₡") and shop_button.text.contains("\n"), "Every upgrade has an item sprite, price and description")
    if OS.get_cmdline_user_args().has("--shop-preview"):
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://.development/upgrade-shop.png")
    await tap(JOY_BUTTON_A)
    check(game.engine_level == 1 and game.credits == 300, "A purchases the focused workshop upgrade exactly once")
    await tap(JOY_BUTTON_DPAD_RIGHT)
    await tap(JOY_BUTTON_DPAD_DOWN)
    check(game.menu_dialogs.workshop_selection == 2, "Direction controls select the tank upgrade")
    await tap(JOY_BUTTON_A)
    check(game.tank_level == 1 and game.credits == 0 and game.taxi.fuel_capacity == 180, "Action purchases the selected tank at its displayed price")
    check(game.menu_dialogs.workshop_selection == 2 and root.gui_get_focus_owner() == game.menu_dialogs.workshop_buttons[2], "Purchase preserves the selected upgrade")
    await tap(JOY_BUTTON_A)
    check(game.tank_level == 1 and game.credits == 0, "Insufficient funds cannot purchase another upgrade")
    await tap(JOY_BUTTON_B)
    game._resume()
    var shop_key := InputEventKey.new()
    shop_key.pressed = true
    shop_key.physical_keycode = KEY_ENTER
    game._input(shop_key)
    game._unhandled_key_input(shop_key)
    check(paused and game.menu_dialogs.visible and game.upgrades.text.contains("ENTER"), "Keyboard Enter opens the shop and updates the landing prompt")
    shop_key.physical_keycode = game.preferences.keys["brake"]
    game.menu_dialogs._input(shop_key)
    check(game.menu_dialogs.workshop_selection == 1, "Keyboard flight directions navigate the shop")
    game.menu_dialogs.close()
    game.retry_button.grab_focus()
    await tap(JOY_BUTTON_A)
    check(game.menu_dialogs.tab == "Retry" and game.lives == 3, "Controller retry asks for confirmation before using a life")
    await tap(JOY_BUTTON_B)
    check(game.lives == 3 and game.screen_state == "paused", "B cancels a retry without losing a life")
    game.retry_button.grab_focus()
    await tap(JOY_BUTTON_A)
    game.menu_dialogs.content.get_child(1).grab_focus()
    await tap(JOY_BUTTON_A)
    check(game.lives == 2 and game.screen_state == "life_lost", "Confirming retry uses exactly one life")
    await tap(JOY_BUTTON_START)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game._controller_connection_changed(0, false)
    check(paused and game.screen_state == "paused", "Disconnecting the active controller pauses the taxi safely")
    await tap(JOY_BUTTON_START)
    game.credits = 9999
    game.lives = 1
    game._lose_life()
    check(game.menu_dialogs.tab == "Score entry", "A controller run can reach the high-score name prompt")
    await tap(JOY_BUTTON_A)
    check(game.menu_dialogs.score_name.text == "A", "On-screen keyboard replaces the prefilled name using the controller")
    var keyboard: GridContainer = game.menu_dialogs.content.get_child(3)
    keyboard.get_child(1).grab_focus()
    await tap(JOY_BUTTON_A)
    check(game.menu_dialogs.score_name.text == "AB", "Controller keyboard enters additional letters")
    keyboard.get_child(37).grab_focus()
    await tap(JOY_BUTTON_A)
    check(game.menu_dialogs.score_name.text == "A", "Controller keyboard can delete a character")
    if DisplayServer.get_name() != "headless":
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://tests/controller-name.png")
    game.menu_dialogs.content.get_child(4).grab_focus()
    await tap(JOY_BUTTON_A)
    check(game.score_recorded and game.high_scores.entries[0]["pilot"] == "A", "A submits the controller-entered leaderboard name")
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
    print("Controller support: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
