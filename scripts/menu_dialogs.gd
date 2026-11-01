extends CenterContainer
var game: Node
var content: VBoxContainer
var binding: String = ""
var binding_button: Button
var notice: Label
var back_button: Button
var tab: String = ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(700, 560)
    panel.add_theme_stylebox_override("panel", game._style(Color("0c1a29"), Color("73e0d3")))
    add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    panel.add_child(box)
    var heading: Label = game._label("", 32, Color("ffc76b"))
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
    return button

func _clear(title: String) -> void:
    binding = ""
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    get_node("PanelContainer/VBoxContainer/Heading").text = title
    game.overlay.visible = false
    visible = true
    notice.text = "Changes apply immediately and are saved."

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
        notice.text = "Click an action, then press its new key. Controller bindings remain available."
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

func show_scores() -> void:
    tab = "Scores"
    _clear("HIGH SCORES")
    notice.text = "Local top 10 finished runs / ranked by final credits."
    var grid := GridContainer.new()
    grid.columns = 6
    grid.add_theme_constant_override("h_separation", 22)
    grid.add_theme_constant_override("v_separation", 9)
    for title in ["#", "PILOT", "CREDITS", "SECTOR", "FARES", "RESULT"]:
        grid.add_child(game._label(title, 13, Color("73e0d3")))
    for index in range(game.high_scores.entries.size()):
        var score: Dictionary = game.high_scores.entries[index]
        for value in [str(index + 1), str(score["pilot"]), str(score["credits"]), "%02d" % score["level"], str(score["fares"]), "COMPLETE" if score["complete"] else "GAME OVER"]:
            grid.add_child(game._label(value, 15))
    content.add_child(grid)
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
    binding = ""
    visible = false
    game.overlay.visible = true
    game.settings_button.grab_focus()
