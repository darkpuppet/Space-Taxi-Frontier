extends CenterContainer
var game: Node
var content: VBoxContainer
var binding: String = ""
var binding_button: Button
var notice: Label
var back_button: Button
var tab: String = ""
var heading: Label
var score_name: LineEdit
var replace_score_name: bool = false
var score_board: Control
var panel: PanelContainer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(700, 560)
    panel.add_theme_stylebox_override("panel", game._style(Color("0c1a29"), Color("73e0d3")))
    add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    panel.add_child(box)
    heading = game._label("", 32, Color("ffc76b"))
    preload("res://scripts/art_deco.gd").skin_title(heading)
    heading.name = "Heading"
    box.add_child(heading)
    content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(content)
    notice = game._label("", 13, Color("73e0d3"))
    box.add_child(notice)
    back_button = _button("BACK / ESC", close)
    box.add_child(back_button)
    visible = false

func _button(text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size.y = 36
    button.pressed.connect(callback)
    preload("res://scripts/art_deco.gd").skin_button(button)
    return button

func _clear(title: String) -> void:
    binding = ""
    panel.custom_minimum_size = Vector2(960, 640) if tab == "Scores" else Vector2(700, 560)
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    heading.text = title
    preload("res://scripts/art_deco.gd").fit_title(heading, 32, 664)
    game.overlay.visible = false
    game.title_ticker.visible = false
    visible = true
    notice.text = "Changes apply immediately and are saved."
    back_button.text = "BACK / ESC"

func show_settings(category: String = "Sound") -> void:
    tab = category
    _clear("SETTINGS")
    var tabs := HBoxContainer.new()
    for label in ["Sound", "Game", "Controls"]:
        tabs.add_child(_button(label, show_settings.bind(label)))
    content.add_child(tabs)
    if category == "Sound":
        for key in ["master", "music", "effects", "voices"]:
            _slider(key.capitalize() + " volume", key, 0, 1, 0.01)
        notice.text = "M toggles mute during flight. Volume levels are saved separately."
    elif category == "Game":
        var row := HBoxContainer.new()
        row.add_child(game._label("Pilot name", 17))
        var name_field := LineEdit.new()
        name_field.text = str(game.preferences.values["pilot"])
        name_field.max_length = 16
        name_field.custom_minimum_size.x = 340
        name_field.text_changed.connect(func(value: String) -> void: game.preferences.set_value("pilot", value))
        row.add_child(name_field)
        content.add_child(row)
        for item in [["Fullscreen", "fullscreen"], ["Camera shake", "camera_shake"], ["Title dispatch ticker", "ticker"]]:
            var toggle := CheckButton.new()
            toggle.text = item[0]
            toggle.button_pressed = bool(game.preferences.values[item[1]])
            toggle.toggled.connect(func(value: bool) -> void: game.preferences.set_value(item[1], value))
            content.add_child(toggle)
    else:
        for item in [["Steer left", "move_left"], ["Steer right", "move_right"], ["Lift thrusters", "thrust"], ["Brake", "brake"]]:
            var action: String = item[1]
            var button: Button = _button(item[0] + " : " + OS.get_keycode_string(game.preferences.keys[action]), func() -> void: pass)
            button.pressed.connect(func() -> void:
                binding = action
                binding_button = button
                button.text = "Press a key... (Esc cancels)"
                notice.text = "Choose an unused key. M, T, R, Enter, Esc and 1-4 are reserved.")
            content.add_child(button)
        _slider("Controller dead zone", "deadzone", 0.05, 0.5, 0.01)
        content.add_child(_button("RESET CONTROLS", func() -> void:
            game.preferences.reset_controls()
            show_settings("Controls")))
        content.add_child(game._label("Stick / D-pad steer | A / RT lift | B / LT brake", 15))
        content.add_child(game._label("Start pause | X dock workshop | Y tow | Back mute", 15))
        notice.text = "Click an action, then press its new key. Controller bindings remain available."
    if game.controller_active and content.get_child_count() > 1:
        content.get_child(0).get_child(0).grab_focus()
    else:
        back_button.grab_focus()

func _slider(label: String, key: String, minimum: float, maximum: float, step: float) -> void:
    var row := HBoxContainer.new()
    var caption: Label = game._label(label, 17)
    caption.custom_minimum_size.x = 230
    row.add_child(caption)
    var slider := HSlider.new()
    slider.min_value = minimum
    slider.max_value = maximum
    slider.step = step
    slider.value = float(game.preferences.values[key])
    slider.custom_minimum_size.x = 320
    row.add_child(slider)
    var value_label: Label = game._label("%d%%" % roundi(slider.value * 100), 16)
    row.add_child(value_label)
    slider.value_changed.connect(func(value: float) -> void:
        value_label.text = "%d%%" % roundi(value * 100)
        game.preferences.set_value(key, value)
        if key == "deadzone": game.preferences.apply_controls())
    content.add_child(row)

func show_score_entry() -> void:
    if game.pending_high_score.is_empty():
        return
    tab = "Score entry"
    _clear("YOU MADE THE TOP TEN!")
    var score: Dictionary = game.pending_high_score
    content.add_child(game._label("₡%d  /  SECTOR %02d  /  %d FARES" % [score["credits"], score["level"], score["fares"]], 20, Color("73e0d3")))
    content.add_child(game._label("Enter your name for the leaderboard", 20))
    score_name = LineEdit.new()
    score_name.max_length = 16
    score_name.text = str(game.preferences.values["pilot"])
    replace_score_name = true
    score_name.text_changed.connect(func(_text: String) -> void: replace_score_name = false)
    score_name.placeholder_text = "Pilot name"
    score_name.custom_minimum_size.y = 44
    score_name.add_theme_font_size_override("font_size", 22)
    score_name.text_submitted.connect(func(_text: String) -> void: _save_score())
    content.add_child(score_name)
    var keyboard := GridContainer.new()
    keyboard.columns = 10
    keyboard.add_theme_constant_override("h_separation", 3)
    keyboard.add_theme_constant_override("v_separation", 3)
    content.add_child(keyboard)
    for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
        var button: Button = _button(letter, func() -> void: _append_name(letter))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        keyboard.add_child(button)
    keyboard.add_child(_button("SPACE", func() -> void: _append_name(" ")))
    keyboard.add_child(_button("DEL", _delete_name))
    content.add_child(_button("SAVE HIGH SCORE / ENTER / A", _save_score))
    notice.text = "Up to 16 characters. Your previous name is filled in for you."
    back_button.text = "SKIP / ESC / B"
    if game.controller_active:
        keyboard.get_child(0).grab_focus()
    else:
        score_name.grab_focus()
        score_name.select_all()

func _append_name(letter: String) -> void:
    if replace_score_name or score_name.has_selection():
        score_name.text = ""
        replace_score_name = false
    if score_name.text.length() < 16:
        score_name.text += letter

func _delete_name() -> void:
    score_name.text = "" if replace_score_name else score_name.text.left(maxi(0, score_name.text.length() - 1))
    replace_score_name = false

func show_workshop() -> void:
    tab = "Workshop"
    _clear("UPGRADE WORKSHOP")
    content.add_child(game._label("BALANCE ₡%d / HULL %d / FUEL %d" % [game.credits, ceili(game.taxi.hull), ceili(game.taxi.fuel)], 20, Color("73e0d3")))
    for item in [["Engine / ₡400", 1], ["Stabilizers / ₡350", 2], ["Fuel tank / ₡300", 3], ["Repair 40 hull / ₡75", 4]]:
        content.add_child(_button(item[0], func() -> void:
            game._purchase_upgrade(item[1])
            show_workshop()
            notice.text = game.banner.text))
    notice.text = "Choose an upgrade with D-pad / stick and A. B returns to Pause."
    content.get_child(1).grab_focus()

func show_retry() -> void:
    tab = "Retry"
    _clear("RESTART THIS LEVEL?")
    content.add_child(game._label("This uses one life and restarts the current sector.\nCredits and upgrades are retained.", 19))
    content.add_child(_button("CONFIRM RETRY / -1 LIFE", func() -> void:
        visible = false
        game._resume()
        game._lose_life("RETRY REQUESTED")))
    notice.text = "B / Back cancels without spending a life."
    back_button.text = "CANCEL / ESC / B"
    back_button.grab_focus()

func _save_score() -> void:
    if game.submit_high_score(score_name.text):
        show_scores()
    else:
        notice.text = "Please enter a name before saving your high score."
        score_name.grab_focus()

func show_scores() -> void:
    tab = "Scores"
    _clear("HIGH SCORES")
    notice.text = "Local top 10 finished runs / ranked by final credits."
    score_board = preload("res://scripts/split_flap_board.gd").new()
    score_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(score_board)
    score_board.set_entries(game.high_scores.entries)
    if game.high_scores.entries.is_empty():
        content.add_child(game._label("No scores yet. Finish a run to claim the first spot!", 18))
    back_button.grab_focus()

func _input(event: InputEvent) -> void:
    if not visible or binding.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
        return
    get_viewport().set_input_as_handled()
    if event.physical_keycode == KEY_ESCAPE:
        show_settings("Controls")
    elif game.preferences.bind_key(binding, event.physical_keycode):
        show_settings("Controls")
    else:
        notice.text = "That key is reserved or already assigned. Choose another key."

func close() -> void:
    if tab == "Score entry" and not game.pending_high_score.is_empty():
        game.skip_high_score()
    binding = ""
    visible = false
    if game.screen_state == "menu":
        game._show_main_menu()
    elif game.screen_state == "paused":
        game._show_pause()
    else:
        game.overlay.visible = true
    game.apply_settings()
    if game.settings_button.visible:
        game.settings_button.grab_focus()
    else:
        game.scores_button.grab_focus()
