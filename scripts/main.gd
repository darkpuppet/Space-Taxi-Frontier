extends Node2D

const TAXI_SCENE: PackedScene = preload("res://Taxi.tscn")
const SAVE_PATH: String = "user://frontier_save.cfg"
var save_file: String = SAVE_PATH
var developer_mode: bool = false
const WORLD = preload("res://scripts/world.gd")
const SPRITES = preload("res://scripts/sprites.gd")
const ART = preload("res://scripts/game_art.gd")
const WIDTH: float = WORLD.WIDTH
const FLOOR: float = WORLD.FLOOR
const CAMPAIGN = preload("res://scripts/campaign.gd")
var explosion: Node2D
var explosion_active: bool = false
var sector: Node2D
var sector_data: Dictionary = {}
var dispatcher = preload("res://scripts/fares.gd").new()
var last_landed_pad: int = 1
var gate_fx: Node2D
var gate_warp: CanvasLayer
var gate_active: bool = false
var gate_position := Vector2.ZERO
var gate_rng := RandomNumberGenerator.new()
var campaign_complete: bool = false
var mission_panel: Label
var taxi: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var objective: Label
var telemetry: Label
var controls: Label
var banner: Label
var upgrades: Label
var fuel_bar: ProgressBar
var hull_bar: ProgressBar
var credits: int = 0
var deliveries: int = 0
var level: int = 0
var source_pad: int = 1
var destination_pad: int = 3
var passenger_onboard: bool = false
var fares_in_level: int = 0
var engine_level: int = 0
var stabilizer_level: int = 0
var tank_level: int = 0
var mission_done: bool = false
var game_over: bool = false
var message_timer: float = 0.0
var pads: Array = []
var stars: Array[Vector2] = []
var pulse: float = 0.0
var audio: Node
var navigation: Label
var status: Label
var shade: ColorRect
var overlay: CenterContainer
var overlay_title: Label
var overlay_copy: Label
var resume_button: Button
var boarding_time: float = 0.0
const PASSENGER_WALK_SPEED: float = 72.0
var passenger_walk: Dictionary = {}
var passenger_accidents: Array[Dictionary] = []
var accident_layer: Node2D
const PASSENGER_STRIKE_FINE: int = 250
var trip_time: float = 0.0
var low_fuel_warned: bool = false
var tow_available: bool = true
var radar: Control
var lives: int = 3
var screen_state: String = "menu"
var menu_button: Button
var exit_button: Button

static func developer_level_from_args(arguments: PackedStringArray) -> int:
    for argument in arguments:
        if argument.begins_with("--dev-level="):
            var value: String = argument.trim_prefix("--dev-level=")
            if value.is_valid_int() and int(value) >= 1 and int(value) <= CAMPAIGN.STAGES.size():
                return int(value)
            return 0
    return 0

func _ready() -> void:
    var developer_level: int = developer_level_from_args(OS.get_cmdline_user_args()) if OS.is_debug_build() else 0
    developer_mode = developer_level > 0
    # Apply the design viewport even when running the scene in an embedded window.
    var window: Window = get_window()
    window.content_scale_size = Vector2i(1280, 720)
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
    window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
    window.unresizable = false
    gate_rng.randomize()
    process_mode = Node.PROCESS_MODE_ALWAYS
    audio = preload("res://scripts/audio.gd").new()
    add_child(audio)
    _load_game()
    for i in range(95):
        stars.append(Vector2(float((i * 337 + 67) % 2400), float((i * 149 + 39) % 480)))
    _build_ui()
    accident_layer = Node2D.new()
    accident_layer.z_index = 6
    add_child(accident_layer)
    accident_layer.draw.connect(_draw_passenger_accidents)
    gate_warp = preload("res://scripts/gate_warp.gd").new()
    add_child(gate_warp)
    if developer_mode:
        _reset_run()
        level = developer_level - 1
        screen_state = "playing"
        _start_level()
        _resume()
        window.title = "Space Taxi: Frontier / DEVELOPER TEST / SAVING DISABLED"
        _announce("DEVELOPER TEST / LEVEL %02d / Career saves disabled." % developer_level)
    else:
        level = 0
        _start_level()
        _show_main_menu()

func _make_pads() -> Array:
    return CAMPAIGN.pads_for(level)

func _start_level() -> void:
    if is_instance_valid(gate_fx):
        gate_fx.queue_free()
    gate_fx = null
    explosion_active = false
    if is_instance_valid(explosion):
        explosion.queue_free()
    explosion = null
    if is_instance_valid(camera):
        camera.offset = Vector2.ZERO
    level = clampi(level, 0, CAMPAIGN.STAGES.size() - 1)
    audio.radio.begin_level(level)
    sector_data = CAMPAIGN.sector(level)
    pads = _make_pads()
    if is_instance_valid(sector):
        sector.queue_free()
    sector = preload("res://scripts/sector.gd").new()
    sector.process_mode = Node.PROCESS_MODE_PAUSABLE
    sector.configure(sector_data)
    add_child(sector)
    dispatcher.configure(level, pads)
    passenger_walk.clear()
    passenger_accidents.clear()
    accident_layer.queue_redraw()
    last_landed_pad = 1
    gate_active = false
    passenger_onboard = false
    fares_in_level = 0
    source_pad = 1
    destination_pad = 3
    mission_done = false
    game_over = false
    boarding_time = 0.0
    trip_time = 0.0
    low_fuel_warned = false
    tow_available = true
    if is_instance_valid(taxi):
        taxi.queue_free()
    taxi = TAXI_SCENE.instantiate()
    taxi.process_mode = Node.PROCESS_MODE_PAUSABLE
    taxi.position = Vector2(float(pads[0]["x"]), float(pads[0]["y"]) - 21.0)
    taxi.pads = pads
    taxi.environment = sector
    taxi.gravity = sector_data["gravity"]
    taxi.landing_horizontal = sector_data["landing_horizontal"]
    taxi.landing_vertical = sector_data["landing_vertical"]
    taxi.world_width = WIDTH
    taxi.floor_height = FLOOR
    taxi.landed_on = 1
    taxi.engine_level = engine_level
    taxi.stabilizer_level = stabilizer_level
    taxi.fuel_capacity = 140.0 + tank_level * 40.0
    taxi.fuel = taxi.fuel_capacity
    add_child(taxi)
    audio.taxi = taxi
    sector.taxi = taxi
    taxi.landed.connect(_on_landed)
    taxi.flight_motion.connect(_on_taxi_flight_motion)
    taxi.damaged.connect(_on_damaged)
    taxi.black_hole_entered.connect(_on_black_hole_entered)
    taxi.black_hole_lost.connect(_on_black_hole_lost)
    if not is_instance_valid(camera):
        camera = Camera2D.new()
        camera.enabled = true
        camera.position_smoothing_enabled = true
        camera.position_smoothing_speed = 4.5
        camera.limit_left = 0
        camera.limit_right = int(WIDTH)
        camera.limit_top = 0
        camera.limit_bottom = int(WORLD.HEIGHT)
        add_child(camera)
    camera.global_position = taxi.position
    camera.reset_smoothing()
    dispatcher.refill(1, taxi.position)
    _sync_dispatch()
    _announce("SECTOR %d / 20 / %s. Waiting rider at PAD %02d." % [level + 1, str(sector_data["name"]), source_pad])
    _refresh_ui()
    queue_redraw()

func _process(dt: float) -> void:
    if is_instance_valid(gate_warp):
        gate_warp.advance(dt)
    if get_tree().paused:
        return
    pulse += dt
    if gate_active and is_instance_valid(gate_fx):
        gate_fx.advance(dt, taxi.position)
    _update_passenger_accidents(dt)
    if explosion_active:
        var finished: bool = explosion.advance(dt)
        camera.offset = explosion.shake_offset()
        if finished:
            explosion_active = false
            camera.offset = Vector2.ZERO
            _lose_life("TAXI DESTROYED")
        return
    if is_instance_valid(taxi) and taxi.hull <= 0 and not game_over and not taxi.capture_active:
        _explode_taxi()
        return
    if is_instance_valid(taxi):
        if not mission_done and not game_over and not taxi.capture_active:
            var departed: Array[int] = dispatcher.tick(dt, taxi.landed_on if taxi.landed_on != -1 else last_landed_pad, taxi.position)
            if not departed.is_empty():
                if departed.has(taxi.landed_on):
                    boarding_time = 0.0
                _announce("Passenger at PAD %02d got tired of waiting and left!" % departed[0])
            _sync_dispatch()
            _update_passenger_accidents(0)
        if gate_active and taxi.landed_on == -1 and not taxi.capture_active and taxi.position.distance_to(gate_position) < 43:
            _enter_star_gate()
            return
        _update_passenger_walk(dt)
        camera.global_position = taxi.global_position
        fuel_bar.max_value = taxi.fuel_capacity
        fuel_bar.value = taxi.fuel
        hull_bar.value = taxi.hull
        telemetry.text = "%06d CR   /   LIVES %d   /   SECTOR %02d / 20" % [credits, lives, level + 1]
        status.text = "FUEL %03d   /   HULL %03d" % [ceili(taxi.fuel), ceili(taxi.hull)]
        upgrades.visible = taxi.landed_on == 2 and not game_over
        radar.taxi_position = taxi.position
        radar.pads = pads
        radar.hazards = sector.navigation_markers()
        radar.fares = dispatcher.waiting
        radar.gate_position = gate_position if gate_active else Vector2(-1, -1)
        radar.target_id = destination_pad if passenger_onboard else source_pad
        radar.queue_redraw()
        var target: Dictionary = pads[(destination_pad if passenger_onboard else maxi(1, source_pad)) - 1]
        var distance: float = float(target["x"]) - taxi.position.x
        var direction: String = "RIGHT >" if distance > 70.0 else "< LEFT"
        if absf(distance) <= 70.0:
            direction = "DESCEND" if taxi.landed_on == -1 else "DOCKED"
        var target_position := Vector2(float(target["x"]), float(target["y"]) - 21)
        var vertical: String = "ASCEND" if target_position.y < taxi.position.y - 45 else "DESCEND"
        navigation.text = "PAD %02d / %s / %04d m\n%s / ALT %04d / SPEED %03d : %03d" % [int(target["id"]), direction, int(taxi.position.distance_to(target_position)), vertical, int(FLOOR - taxi.position.y), int(absf(taxi.velocity.x)), int(absf(taxi.velocity.y))]
        var waiting_text: String = ""
        for fare in dispatcher.waiting:
            waiting_text += "PAD %02d > %02d  %ds   " % [int(fare["source"]), int(fare["destination"]), ceili(float(fare["patience"]))]
        mission_panel.text = "%02d / %s\nDELIVERED %d / 3   |   MISSED %d   |   LOST %d\n%s\n%s" % [level + 1, str(sector_data["name"]), fares_in_level, dispatcher.missed, dispatcher.killed, str(sector_data["hint"]), waiting_text]
        if gate_active:
            navigation.text = "STAR GATE / %04d m\nFLY THROUGH TO %s" % [int(taxi.position.distance_to(gate_position)), "FINISH" if level == 19 else "NEXT LEVEL"]
        if passenger_onboard and not game_over:
            trip_time += dt
        elif not dispatcher.at_pad(taxi.landed_on).is_empty() and not mission_done and not game_over and not taxi.capture_active:
            boarding_time += dt
            if boarding_time >= 1.0 and _passenger_at_door():
                _board_passenger()
        else:
            boarding_time = 0.0
        if taxi.fuel < 20.0 and not low_fuel_warned:
            low_fuel_warned = true
            audio.cue("low")
            _announce("LOW FUEL / Dock at PAD 02. Press T for one emergency tow per shift.")
    if message_timer > 0.0:
        message_timer -= dt
    banner.modulate.a = minf(1.0, maxf(message_timer, 0.0))
    queue_redraw()

func _draw() -> void:
    preload("res://scripts/scenery.gd").paint(self, sector_data, pulse, WORLD.HEIGHT)
    for tile in range(10):
        ART.hazard(self, ART.Hazard.FLOOR, Rect2(tile * 240, FLOOR, 240, 40))
    for pad in pads:
        var px: float = float(pad["x"])
        var py: float = float(pad["y"])
        var pw: float = float(pad["width"])
        var id: int = int(pad["id"])
        var waiting_fare: Dictionary = dispatcher.at_pad(id)
        var active: bool = not mission_done and ((passenger_onboard and id == destination_pad) or not waiting_fare.is_empty())
        var impatient: bool = not waiting_fare.is_empty() and float(waiting_fare["patience"]) < 15
        var accent: Color = Color("ff806e") if impatient else (Color("ffc76b") if active else Color("5ac8cf"))
        var left: float = px - pw * 0.5
        if active:
            var beam := PackedVector2Array([Vector2(left + 18, py), Vector2(left - 12, py - 110), Vector2(left + pw + 12, py - 110), Vector2(left + pw - 18, py)])
            draw_colored_polygon(beam, Color(accent.r, accent.g, accent.b, 0.035 + sin(pulse * 3.0) * 0.012))
            draw_line(Vector2(left + 18, py - 5), Vector2(left + 18, py - 80), Color(accent.r, accent.g, accent.b, 0.25), 1)
            draw_line(Vector2(left + pw - 18, py - 5), Vector2(left + pw - 18, py - 80), Color(accent.r, accent.g, accent.b, 0.25), 1)
        var art = preload("res://scripts/bitmap_art.gd")
        for side in [-1, 1]:
            art.supports(self, px + side * pw * 0.3, py + 27, FLOOR)
        var platform_style: int = 2 if level in [4, 7, 12, 14, 16] else (1 if level in [1, 3, 5, 11, 13, 17] else 0)
        art.sprite(self, platform_style, Rect2(left, py, pw, 27))
        draw_line(Vector2(left + 4, py + 1), Vector2(left + pw - 4, py + 1), accent, 2)
        for side in [-1, 1]:
            art.sprite(self, 4, Rect2(px + side * (pw * 0.5 - 9) - 6, py - 17, 12, 17))
            draw_circle(Vector2(px + side * (pw * 0.5 - 9), py - 11), 6, Color(accent.r, accent.g, accent.b, 0.12 + sin(pulse * 3) * 0.04))
        art.sprite(self, 5, Rect2(left + pw - 32, py - 29, 18, 29))
        var label: String = "%02d / %s" % [id, "SERVICE" if id == 2 else "TERMINAL"]
        if active:
            label = "%02d / %s" % [id, "ARRIVALS" if passenger_onboard and id == destination_pad else "PICKUP %ds" % ceili(float(waiting_fare["patience"]))]
        var label_width: float = ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16
        draw_rect(Rect2(left, py + 28, label_width, 20), Color("0c1924dd"))
        draw_string(ThemeDB.fallback_font, Vector2(left + 8, py + 43), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent)
        if not waiting_fare.is_empty() and not mission_done:
            var walk: Dictionary = passenger_walk.get(int(waiting_fare["id"]), {})
            var person := Vector2(float(walk.get("x", _fare_home_x(pad))), py - 2)
            var variant: int = _passenger_variant(waiting_fare)
            if walk.get("moving", false):
                SPRITES.walking_rider(self, person, variant, float(walk["clock"]), float(walk["direction"]))
            elif impatient:
                SPRITES.impatient_rider(self, person, variant, pulse + int(waiting_fare["id"]) * 0.17)
            else:
                var pose: int = int(pulse * 3.0 + int(waiting_fare["id"])) % 3
                SPRITES.rider(self, person, variant, pose)
            draw_string(ThemeDB.fallback_font, person + Vector2(-34, -58), "%ds / PAD %02d" % [ceili(float(waiting_fare["patience"])), int(waiting_fare["destination"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
        if id == 2:
            art.sprite(self, 3, Rect2(left + 19, py - 49, 32, 49))
            art.sprite(self, 8, Rect2(left + 57, py - 31, 18, 31))
            art.sprite(self, 7, Rect2(left + 13, py + 53, 27, 22))


func _style(color: Color, border: Color = Color("29434f")) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style

func _label(text: String, size: int, color: Color = Color("d2e6e9")) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _build_ui() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(root)
    var box := PanelContainer.new()
    box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    box.offset_left = 24
    box.offset_right = -24
    box.offset_top = 20
    box.add_theme_stylebox_override("panel", _style(Color("0c1924ed")))
    root.add_child(box)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 9)
    box.add_child(stack)
    var title_row := HBoxContainer.new()
    stack.add_child(title_row)
    var heading := _label("SPACE TAXI  /  FRONTIER", 22, Color("ffc76b"))
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(heading)
    telemetry = _label("", 15)
    title_row.add_child(telemetry)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    stack.add_child(row)
    objective = _label("", 15, Color("73e0d3"))
    objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(objective)
    status = _label("", 13)
    row.add_child(status)
    fuel_bar = ProgressBar.new()
    fuel_bar.custom_minimum_size = Vector2(110, 10)
    fuel_bar.show_percentage = false
    fuel_bar.add_theme_stylebox_override("background", _style(Color("1c303e")))
    fuel_bar.add_theme_stylebox_override("fill", _style(Color("67d9ba"), Color("67d9ba")))
    row.add_child(fuel_bar)
    hull_bar = ProgressBar.new()
    hull_bar.custom_minimum_size = Vector2(110, 10)
    hull_bar.show_percentage = false
    hull_bar.add_theme_stylebox_override("background", _style(Color("1c303e")))
    hull_bar.add_theme_stylebox_override("fill", _style(Color("ffc76b"), Color("ffc76b")))
    row.add_child(hull_bar)
    var dispatch_backing := Panel.new()
    dispatch_backing.position = Vector2(24, 122)
    dispatch_backing.size = Vector2(370, 184)
    dispatch_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dispatch_backing.add_theme_stylebox_override("panel", _style(Color("0c1924dc")))
    root.add_child(dispatch_backing)
    navigation = _label("", 14, Color("a6cedb"))
    navigation.position = Vector2(42, 131)
    root.add_child(navigation)
    mission_panel = _label("", 12, Color("a3c5d0"))
    mission_panel.position = Vector2(42, 215)
    root.add_child(mission_panel)
    radar = preload("res://scripts/radar.gd").new()
    radar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    radar.position = Vector2(-302, 131)
    radar.size = Vector2(260, 155)
    root.add_child(radar)
    var bottom := PanelContainer.new()
    bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_left = 24
    bottom.offset_right = -24
    bottom.offset_top = -102
    bottom.offset_bottom = -20
    bottom.add_theme_stylebox_override("panel", _style(Color("0c1924ed")))
    root.add_child(bottom)
    var bottom_stack := VBoxContainer.new()
    bottom.add_child(bottom_stack)
    banner = _label("", 15, Color("ffc76b"))
    bottom_stack.add_child(banner)
    controls = _label("A / D  STEER     W / SPACE  LIFT     S  BRAKE     ESC  PAUSE     M  SOUND     T  TOW     R  RETRY (-1 LIFE)", 12, Color("7d9aa9"))
    bottom_stack.add_child(controls)
    upgrades = _label("SERVICE / 1 Engine 400 CR | 2 Stabilizers 350 CR
3 Tank 300 CR | 4 Repair 75 CR", 14, Color("73e0d3"))
    upgrades.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    upgrades.position = Vector2(-460, -165)
    upgrades.visible = false
    root.add_child(upgrades)
    shade = ColorRect.new()
    shade.color = Color(0.015, 0.03, 0.05, 0.88)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(shade)
    overlay = CenterContainer.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(overlay)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(640, 430)
    panel.add_theme_stylebox_override("panel", _style(Color("101f2d"), Color("496473")))
    overlay.add_child(panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 18)
    panel.add_child(content)
    content.add_child(_label("F R O N T I E R   /   F L I G H T   O P E R A T I O N S", 14, Color("73e0d3")))
    overlay_title = _label("SPACE TAXI", 52, Color("ffc76b"))
    content.add_child(overlay_title)
    overlay_copy = _label("", 18)
    content.add_child(overlay_copy)
    resume_button = Button.new()
    resume_button.text = "BEGIN SHIFT   /   ENTER"
    resume_button.custom_minimum_size.y = 52
    resume_button.add_theme_font_size_override("font_size", 18)
    resume_button.add_theme_stylebox_override("normal", _style(Color("284450"), Color("73e0d3")))
    resume_button.add_theme_stylebox_override("hover", _style(Color("365f69"), Color("ffc76b")))
    resume_button.pressed.connect(_primary_action)
    content.add_child(resume_button)
    menu_button = Button.new()
    menu_button.text = "RETURN TO MAIN MENU"
    menu_button.custom_minimum_size.y = 40
    menu_button.pressed.connect(_return_to_menu)
    content.add_child(menu_button)
    exit_button = Button.new()
    exit_button.text = "EXIT GAME"
    exit_button.custom_minimum_size.y = 40
    exit_button.pressed.connect(_exit_game)
    content.add_child(exit_button)
    content.add_child(_label("Original procedural graphics & synthesized soundtrack  /  v0.7", 12, Color("7d9aa9")))

func _open_overlay(title: String, copy: String, action: String) -> void:
    get_tree().paused = true
    overlay.visible = true
    shade.visible = true
    overlay_title.text = title
    overlay_copy.text = copy
    resume_button.text = action
    menu_button.visible = screen_state != "menu"
    resume_button.grab_focus()

func _show_main_menu() -> void:
    audio.radio.reset()
    screen_state = "menu"
    _open_overlay("SPACE TAXI", "FRONTIER / A 20-sector arcade campaign\n\nEvery new game begins at Level 1 with 3 lives.\nA / D steer. W / SPACE lift. S brake to land.\nCollect waiting riders before their patience runs out.\nThree deliveries open the star gate to the next level.", "NEW GAME / LEVEL 1 / ENTER")

func _show_pause(_briefing: bool = false) -> void:
    screen_state = "paused"
    _open_overlay("FLIGHT PAUSED", "LEVEL %02d / %s\nLIVES %d / 3   |   FARES %d / 3\n\nA / D steer  /  W or SPACE lift  /  S brake\nDeliver three fares, then fly through the star gate.\nWaiting riders leave when their timers reach zero." % [level + 1, str(sector_data["name"]), lives, fares_in_level], "RESUME FLIGHT / ENTER")

func _primary_action() -> void:
    if screen_state in ["menu", "game_over", "campaign_complete"]:
        _new_game()
    else:
        _resume()

func _reset_run() -> void:
    audio.radio.reset_campaign()
    level = 0
    lives = 3
    credits = 0
    deliveries = 0
    engine_level = 0
    stabilizer_level = 0
    tank_level = 0
    campaign_complete = false

func _new_game() -> void:
    _reset_run()
    screen_state = "playing"
    _start_level()
    _save_game()
    _resume()

func _return_to_menu() -> void:
    _reset_run()
    _start_level()
    _save_game()
    _show_main_menu()

func _exit_game() -> void:
    _save_game()
    audio.shutdown()
    await get_tree().create_timer(0.2).timeout
    get_tree().quit()

func _resume() -> void:
    if screen_state in ["menu", "game_over", "campaign_complete"]:
        _new_game()
        return
    if screen_state == "life_lost":
        _start_level()
    screen_state = "playing"
    overlay.visible = false
    shade.visible = false
    get_tree().paused = false
    _sync_dispatch()

func _explode_taxi() -> void:
    if explosion_active or screen_state != "playing":
        return
    audio.radio.silence()
    explosion_active = true
    game_over = true
    taxi.input_locked = true
    taxi.engine_on = false
    taxi.visible = false
    hull_bar.value = 0
    status.text = "FUEL %03d   /   HULL 000" % ceili(taxi.fuel)
    sector.set_physics_process(false)
    explosion = preload("res://scripts/explosion.gd").new()
    add_child(explosion)
    explosion.ignite(taxi.position, taxi.velocity)
    taxi.velocity = Vector2.ZERO
    audio.cue("explosion")
    _announce("TAXI DESTROYED / That'll buff right out...")

func _lose_life(reason: String = "TAXI DESTROYED") -> void:
    if screen_state != "playing" or explosion_active:
        return
    lives = maxi(0, lives - 1)
    telemetry.text = "%06d CR   /   LIVES %d   /   SECTOR %02d / 20" % [credits, lives, level + 1]
    game_over = true
    taxi.input_locked = true
    taxi.engine_on = false
    _save_game()
    if lives > 0:
        screen_state = "life_lost"
        _open_overlay("TAXI LOST", "%s\n\n%d %s remaining.\nRetry Level %02d with a repaired, refueled taxi.\nThis sector's fares restart; earned upgrades remain." % [reason, lives, "life" if lives == 1 else "lives", level + 1], "RETRY LEVEL %02d / ENTER" % (level + 1))
    else:
        screen_state = "game_over"
        _open_overlay("GAME OVER", "All three taxis lost.\nYou reached Level %02d and completed %d fares.\n\nStart a new game at Level 1 with three fresh lives,\nor return to the main menu." % [level + 1, deliveries], "NEW GAME / LEVEL 1 / ENTER")

func _sync_dispatch() -> void:
    if screen_state == "playing" and not mission_done and not explosion_active:
        audio.radio.sync_fares(dispatcher.waiting, audio.muted)
    if passenger_onboard:
        return
    var recommended: Dictionary = dispatcher.suggested(taxi.position)
    source_pad = int(recommended["source"]) if not recommended.is_empty() else 0
    _refresh_ui()

func _passenger_variant(fare: Dictionary) -> int:
    return posmod(int(fare["id"]) - 1 + level, 3)

func _update_passenger_accidents(dt: float) -> void:
    for index in range(passenger_accidents.size() - 1, -1, -1):
        var accident: Dictionary = passenger_accidents[index]
        accident["age"] += dt
        # Keep the memorial until replacement, then dissolve it into the pad.
        if accident.has("dissolve_age"):
            accident["dissolve_age"] += dt
            if float(accident["dissolve_age"]) >= preload("res://scripts/passenger_accident_fx.gd").DISSOLVE_DURATION:
                passenger_accidents.remove_at(index)
        elif float(accident["age"]) >= 3.0 and (dispatcher.serial > int(accident["spawn_serial"]) or mission_done):
            accident["dissolve_age"] = 0.0
    accident_layer.queue_redraw()

func _draw_passenger_accidents() -> void:
    for accident in passenger_accidents:
        preload("res://scripts/passenger_accident_fx.gd").draw(accident_layer, accident)

func _fare_home_x(pad: Dictionary) -> float:
    return float(pad["x"]) + minf(46.0, float(pad["width"]) * 0.5 - 8.0)

func _on_taxi_flight_motion(start: Vector2, finish: Vector2) -> void:
    if game_over or mission_done or taxi.capture_active or finish.y <= start.y:
        return
    # Swept hull against standing passenger bounds, before landing can start boarding.
    for fare in dispatcher.waiting.duplicate():
        var fare_id: int = int(fare["id"])
        var pad: Dictionary = pads[int(fare["source"]) - 1]
        var person := Vector2(float(passenger_walk.get(fare_id, {}).get("x", _fare_home_x(pad))), float(pad["y"]) - 2)
        var hit: Dictionary = sector._box_hit(start, finish, person + Vector2(0, -21), Vector2(43, 42))
        if not hit.is_empty() and dispatcher.kill(fare_id):
            passenger_walk.erase(fare_id)
            boarding_time = 0.0
            credits -= PASSENGER_STRIKE_FINE
            var alien: bool = _passenger_variant(fare) == 1
            passenger_accidents.append({"position": person, "age": 0.0, "spawn_serial": dispatcher.serial, "alien": alien, "color": Color("75ee45") if alien else Color("e34443")})
            accident_layer.queue_redraw()
            audio.cue("squish")
            audio.cue("scream_alien" if alien else "scream_human")
            _sync_dispatch()
            _announce("PASSENGER KILLED / -250 CR fine. Land clear of waiting riders!")
            _save_game()
            queue_redraw()

func _update_passenger_walk(dt: float) -> void:
    var present: Dictionary = {}
    for fare in dispatcher.waiting:
        var fare_id: int = int(fare["id"])
        present[fare_id] = true
        var pad: Dictionary = pads[int(fare["source"]) - 1]
        var home_x: float = _fare_home_x(pad)
        if not passenger_walk.has(fare_id):
            passenger_walk[fare_id] = {"x": home_x, "clock": 0.0, "direction": 1.0, "moving": false}
        var walk: Dictionary = passenger_walk[fare_id]
        var approaching: bool = taxi.landed_on == int(fare["source"]) and not passenger_onboard and not mission_done and not game_over and not taxi.capture_active
        var target_x: float = taxi.position.x if approaching else home_x
        var distance: float = target_x - float(walk["x"])
        walk["moving"] = absf(distance) > 0.5
        if walk["moving"]:
            walk["direction"] = signf(distance)
            walk["clock"] += dt
            walk["x"] = move_toward(float(walk["x"]), target_x, PASSENGER_WALK_SPEED * dt)
    for fare_id in passenger_walk.keys():
        if not present.has(fare_id):
            passenger_walk.erase(fare_id)

func _passenger_at_door() -> bool:
    var fare: Dictionary = dispatcher.at_pad(taxi.landed_on)
    if fare.is_empty():
        return false
    var walk: Dictionary = passenger_walk.get(int(fare["id"]), {})
    return not walk.is_empty() and absf(float(walk["x"]) - taxi.position.x) <= 0.5

func _board_passenger() -> void:
    if not dispatcher.board(taxi.landed_on):
        return
    passenger_walk.erase(int(dispatcher.active["id"]))
    passenger_onboard = true
    destination_pad = int(dispatcher.active["destination"])
    audio.radio.announce_destination(int(dispatcher.active["id"]), destination_pad, _passenger_variant(dispatcher.active), audio.muted)
    boarding_time = 0.0
    trip_time = 0.0
    audio.cue("pickup")
    _announce("Passenger aboard! Destination PAD %02d." % destination_pad)
    _refresh_ui()

func _open_star_gate() -> void:
    gate_active = true
    taxi.refuel(35.0)
    dispatcher.waiting.clear()
    gate_position = _choose_gate_position()
    if is_instance_valid(gate_fx):
        gate_fx.queue_free()
    gate_fx = preload("res://scripts/stargate_fx.gd").new()
    add_child(gate_fx)
    gate_fx.activate(gate_position)
    sector.exit_open = true
    sector.exit_position = gate_position
    audio.radio.announce_gate(audio.muted)
    audio.cue("complete")
    _announce("LAST FARE / +35 departure fuel. Fly through the star gate to %s." % ("finish the campaign" if level == 19 else "reach the next level"))

func _gate_spot_clear(point: Vector2, clearance: float = 75.0) -> bool:
    if point.x < 110 or point.x > WIDTH - 110 or point.y < 165 or point.y > FLOOR - 110:
        return false
    if sector.resolve_motion(point, point, Vector2.ZERO, clearance).get("collided", false):
        return false
    for pad in pads:
        var platform := Rect2(float(pad["x"]) - float(pad["width"]) * 0.5, float(pad["y"]), float(pad["width"]), 25)
        if platform.grow(clearance).has_point(point):
            return false
    for hole in sector.holes:
        var home: Vector2 = hole["home"]
        var danger := Rect2(home - Vector2(float(hole["drift"]) + 115, 140), Vector2((float(hole["drift"]) + 115) * 2, 280))
        if danger.has_point(point):
            return false
    return true

func _gate_navigation() -> Dictionary:
    var grid := AStarGrid2D.new()
    grid.region = Rect2i(0, 0, 36, WORLD.NAV_ROWS)
    grid.cell_size = Vector2(64, 64)
    grid.offset = Vector2(64, 144)
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()
    var launch: Vector2 = taxi.position + Vector2(0, -80) if taxi.landed_on != -1 else taxi.position
    var start := Vector2i.ZERO
    var best: float = INF
    for y in range(WORLD.NAV_ROWS):
        for x in range(36):
            var id := Vector2i(x, y)
            var point: Vector2 = grid.get_point_position(id)
            var blocked: bool = sector.resolve_motion(point, point, Vector2.ZERO, 39).get("collided", false)
            for pad in pads:
                var platform := Rect2(float(pad["x"]) - float(pad["width"]) * 0.5, float(pad["y"]), float(pad["width"]), 25)
                if platform.grow(39).has_point(point):
                    blocked = true
            for hole in sector.holes:
                var home: Vector2 = hole["home"]
                var half := Vector2(float(hole["drift"]) + 80, 110)
                if Rect2(home - half, half * 2).has_point(point):
                    blocked = true
            grid.set_point_solid(id, blocked)
            if not blocked:
                grid.set_point_weight_scale(id, 1.0 + pow(sector.field_at(point).length() / 55.0, 2.0))
            if not blocked and point.distance_squared_to(launch) < best:
                best = point.distance_squared_to(launch)
                start = id
    return {"grid": grid, "start": start}

func _choose_gate_position() -> Vector2:
    var navigation: Dictionary = _gate_navigation()
    var grid: AStarGrid2D = navigation["grid"]
    var candidates: Array[Vector2] = []
    for y in range(1, WORLD.NAV_ROWS - 1):
        for x in range(1, 35):
            var id := Vector2i(x, y)
            var point: Vector2 = grid.get_point_position(id)
            if point.distance_to(taxi.position) < 550 or not _gate_spot_clear(point, 90):
                continue
            if not grid.get_id_path(navigation["start"], id).is_empty():
                candidates.append(point)
    if candidates.is_empty():
        # The open upper lane is a reachable fallback if a moving hazard blocks
        # every lower candidate at the exact moment the shift ends.
        for x in range(160, 2250, 80):
            var point := Vector2(x, 170)
            if _gate_spot_clear(point):
                candidates.append(point)
    if candidates.is_empty():
        return Vector2(clampf(taxi.position.x + 600, 120, WIDTH - 120), 170)
    var chosen: Vector2 = candidates[gate_rng.randi_range(0, candidates.size() - 1)]
    var jitter := Vector2(gate_rng.randf_range(-12, 12), gate_rng.randf_range(-12, 12))
    return chosen + jitter if _gate_spot_clear(chosen + jitter) else chosen

func _enter_star_gate() -> void:
    if not gate_active or not mission_done or taxi.landed_on != -1 or taxi.position.distance_to(gate_position) >= 43:
        return
    gate_active = false
    gate_warp.trigger()
    audio.cue("service")
    if level < CAMPAIGN.STAGES.size() - 1:
        level += 1
        _save_game()
        _start_level()
    else:
        campaign_complete = true
        _save_game()
        _refresh_ui()
        screen_state = "campaign_complete"
        _open_overlay("FRONTIER COMPLETE", "All 20 sectors served!\n%d fares delivered with %d lives remaining.\n\nYour taxi has earned a well-deserved rest." % [deliveries, lives], "NEW GAME / LEVEL 1 / ENTER")

func _refresh_ui() -> void:
    if mission_done and campaign_complete:
        objective.text = "FRONTIER COMPLETE / 20 SECTORS SERVED"
    elif mission_done:
        objective.text = "SHIFT COMPLETE > FLY THROUGH THE STAR GATE"
    elif passenger_onboard:
        objective.text = "PASSENGER ONBOARD > PAD %02d" % destination_pad
    elif source_pad > 0:
        objective.text = "PICKUP > PAD %02d / %d WAITING" % [source_pad, dispatcher.waiting.size()]
    else:
        objective.text = "WAITING FOR DISPATCH"

func _announce(text: String) -> void:
    banner.text = text
    message_timer = 6.0

func _on_landed(pad_id: int) -> void:
    if game_over:
        return
    last_landed_pad = pad_id
    audio.cue("land")
    if pad_id == 2:
        taxi.refuel(40.0)
        audio.cue("service")
        _announce("Service station: +40 fuel. Buy upgrades with keys 1-4.")
    if mission_done:
        return
    if passenger_onboard and pad_id == destination_pad:
        passenger_onboard = false
        dispatcher.finish()
        var fare: int = 220 + level * 85 + (fares_in_level * 65) + maxi(0, int(60.0 - trip_time)) * 2
        credits += fare
        deliveries += 1
        fares_in_level += 1
        _save_game()
        if fares_in_level >= int(sector_data["fares"]):
            mission_done = true
            _open_star_gate()
        else:
            audio.cue("fare")
            boarding_time = 0.0
            dispatcher.refill(pad_id, taxi.position)
            _sync_dispatch()
            _announce("Fare paid: %d credits! Next pickup at PAD %02d." % [fare, source_pad])
    _refresh_ui()

func _on_black_hole_entered(_center: Vector2) -> void:
    audio.cue("suction")
    _announce("MY METER'S STILL RUNNING! / Complimentary spaghetti upgrade...")

func _on_black_hole_lost() -> void:
    _lose_life("BLACK HOLE / Your taxi has been upgraded to spaghetti.")

func _on_damaged(amount: float) -> void:
    audio.cue("impact")
    _announce("%s / -%d hull. Brake early and steer clear of hazards." % [taxi.last_damage_reason, int(amount)])

func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo:
        return
    if event.physical_keycode == KEY_M:
        var silent: bool = audio.toggle_mute()
        _announce("SOUND OFF" if silent else "SOUND ON")
        return
    if event.physical_keycode == KEY_ESCAPE:
        if screen_state == "paused":
            _resume()
        elif screen_state == "playing":
            _show_pause()
        return
    if get_tree().paused:
        if event.physical_keycode == KEY_ENTER:
            _primary_action()
        return
    if taxi.capture_active or explosion_active:
        return
    if event.physical_keycode == KEY_T and not game_over and tow_available:
        tow_available = false
        credits -= mini(100, maxi(0, credits))
        taxi.position = Vector2(float(pads[1]["x"]), float(pads[1]["y"]) - 21.0)
        taxi.velocity = Vector2.ZERO
        taxi.landed_on = 2
        last_landed_pad = 2
        taxi.engine_on = false
        taxi.refuel(45.0)
        audio.cue("service")
        _announce("Emergency tow to PAD 02. Up to 100 CR charged. Tow used for this shift.")
        _save_game()
        return
    if event.physical_keycode == KEY_R:
        _lose_life("RETRY REQUESTED")
    elif taxi.landed_on == 2 and not game_over and event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
        var key: int = event.physical_keycode
        if key == KEY_1 and credits >= 400 and engine_level < 4:
            credits -= 400
            engine_level += 1
            taxi.engine_level = engine_level
            _announce("Engine upgraded to Mk %d." % engine_level)
        elif key == KEY_2 and credits >= 350 and stabilizer_level < 4:
            credits -= 350
            stabilizer_level += 1
            taxi.stabilizer_level = stabilizer_level
            _announce("Stabilizers upgraded to Mk %d." % stabilizer_level)
        elif key == KEY_3 and credits >= 300 and tank_level < 4:
            credits -= 300
            tank_level += 1
            taxi.fuel_capacity = 140.0 + tank_level * 40.0
            taxi.refuel(40.0)
            _announce("Fuel capacity upgraded to Mk %d." % tank_level)
        elif key == KEY_4 and credits >= 75 and taxi.hull < 100.0:
            credits -= 75
            taxi.repair(40.0)
            _announce("Hull repaired by 40 points.")
        else:
            _announce("Upgrade unavailable: check credits, level cap, or hull.")
        _save_game()

func _save_game() -> void:
    if developer_mode:
        return
    var cfg: ConfigFile = ConfigFile.new()
    cfg.set_value("career", "lives", lives)
    cfg.set_value("career", "credits", credits)
    cfg.set_value("career", "deliveries", deliveries)
    cfg.set_value("career", "level", level)
    cfg.set_value("career", "campaign_complete", campaign_complete)
    cfg.set_value("upgrades", "engine", engine_level)
    cfg.set_value("upgrades", "stabilizers", stabilizer_level)
    cfg.set_value("upgrades", "tank", tank_level)
    cfg.save(save_file)

func _load_game() -> void:
    if developer_mode:
        return
    var cfg: ConfigFile = ConfigFile.new()
    if cfg.load(save_file) != OK:
        return
    lives = clampi(int(cfg.get_value("career", "lives", 3)), 0, 3)
    credits = int(cfg.get_value("career", "credits", 0))
    deliveries = int(cfg.get_value("career", "deliveries", 0))
    level = clampi(int(cfg.get_value("career", "level", 0)), 0, CAMPAIGN.STAGES.size() - 1)
    campaign_complete = bool(cfg.get_value("career", "campaign_complete", false))
    engine_level = clampi(int(cfg.get_value("upgrades", "engine", 0)), 0, 4)
    stabilizer_level = clampi(int(cfg.get_value("upgrades", "stabilizers", 0)), 0, 4)
    tank_level = clampi(int(cfg.get_value("upgrades", "tank", 0)), 0, 4)
