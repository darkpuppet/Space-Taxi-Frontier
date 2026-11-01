extends RefCounted
signal changed
const DEFAULTS: Dictionary = {
    "master": 1.0, "music": 1.0, "effects": 1.0, "voices": 1.0,
    "fullscreen": false, "camera_shake": true, "ticker": true,
    "deadzone": 0.2, "pilot": "Pilot"
}
const DEFAULT_KEYS: Dictionary = {"move_left": KEY_A, "move_right": KEY_D, "thrust": KEY_W, "brake": KEY_S}
var path: String = "user://frontier_settings.cfg"
var values: Dictionary = DEFAULTS.duplicate()
var keys: Dictionary = DEFAULT_KEYS.duplicate()

func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(path) == OK:
        for key in DEFAULTS:
            var value = cfg.get_value("settings", key, DEFAULTS[key])
            if typeof(value) == typeof(DEFAULTS[key]):
                values[key] = value
        for action in keys:
            var value = cfg.get_value("keys", action, keys[action])
            if value is int and value > 0:
                keys[action] = value
        for key in ["master", "music", "effects", "voices"]:
            values[key] = clampf(float(values[key]), 0, 1)
        values["deadzone"] = clampf(float(values["deadzone"]), 0.05, 0.5)
        values["pilot"] = str(values["pilot"]).strip_edges().left(16)
    apply_controls()

func set_value(key: String, value: Variant) -> void:
    values[key] = value
    save_settings()
    changed.emit()

func bind_key(action: String, key: int) -> bool:
    if key in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_M, KEY_T, KEY_R, KEY_1, KEY_2, KEY_3, KEY_4]:
        return false
    for other in keys:
        if other != action and int(keys[other]) == key:
            return false
    keys[action] = key
    apply_controls()
    save_settings()
    changed.emit()
    return true

func apply_controls() -> void:
    for action in keys:
        # Keep controller bindings; replace keyboard bindings so rebinding is real.
        for event in InputMap.action_get_events(action):
            if event is InputEventKey:
                InputMap.action_erase_event(action, event)
        var key := InputEventKey.new()
        key.physical_keycode = int(keys[action])
        InputMap.action_add_event(action, key)
        if keys == DEFAULT_KEYS:
            var alternate := InputEventKey.new()
            alternate.physical_keycode = {"move_left": KEY_LEFT, "move_right": KEY_RIGHT, "thrust": KEY_UP, "brake": KEY_DOWN}[action]
            InputMap.action_add_event(action, alternate)
            if action == "thrust":
                var space := InputEventKey.new()
                space.physical_keycode = KEY_SPACE
                InputMap.action_add_event(action, space)
        InputMap.action_set_deadzone(action, float(values["deadzone"]))
    for item in [["move_left", JOY_BUTTON_DPAD_LEFT], ["move_right", JOY_BUTTON_DPAD_RIGHT], ["thrust", JOY_BUTTON_A], ["brake", JOY_BUTTON_B], ["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B], ["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT], ["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN]]:
        var button := InputEventJoypadButton.new()
        button.button_index = item[1]
        _ensure_event(item[0], button)
    for item in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["thrust", JOY_AXIS_TRIGGER_RIGHT, 1.0], ["brake", JOY_AXIS_TRIGGER_LEFT, 1.0], ["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0], ["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0]]:
        var axis := InputEventJoypadMotion.new()
        axis.axis = item[1]
        axis.axis_value = item[2]
        _ensure_event(item[0], axis)

func _ensure_event(action: String, event: InputEvent) -> void:
    event.device = -1
    for existing in InputMap.action_get_events(action):
        var matches: bool = (existing is InputEventJoypadButton and event is InputEventJoypadButton and existing.button_index == event.button_index) or (existing is InputEventJoypadMotion and event is InputEventJoypadMotion and existing.axis == event.axis and signf(existing.axis_value) == signf(event.axis_value))
        if matches:
            if existing.device == -1:
                return
            InputMap.action_erase_event(action, existing)
    InputMap.action_add_event(action, event)

func reset_controls() -> void:
    keys = DEFAULT_KEYS.duplicate()
    values["deadzone"] = 0.2
    apply_controls()
    save_settings()
    changed.emit()

func save_settings() -> void:
    var cfg := ConfigFile.new()
    for key in values:
        cfg.set_value("settings", key, values[key])
    for action in keys:
        cfg.set_value("keys", action, keys[action])
    cfg.save(path)

func control_hint(controller: bool = false) -> String:
    if controller:
        return "STICK / D-PAD STEER   A / RT LIFT   B / LT BRAKE"
    return "%s / %s STEER   %s LIFT   %s BRAKE" % [OS.get_keycode_string(keys["move_left"]), OS.get_keycode_string(keys["move_right"]), OS.get_keycode_string(keys["thrust"]), OS.get_keycode_string(keys["brake"])]
