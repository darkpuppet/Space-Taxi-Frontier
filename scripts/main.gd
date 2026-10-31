extends Node2D

const TAXI_SCENE: PackedScene = preload("res://Taxi.tscn")
const SAVE_PATH: String = "user://frontier_save.cfg"
const WIDTH: float = 2400.0
const FLOOR: float = 680.0
const LEVEL_NAMES: Array[String] = ["ORBITAL REFINERY", "DUST COLONY", "ICE MOON", "DEEP-SPACE TERMINAL"]
const LEVEL_COLORS: Array[Color] = [Color("102431"), Color("38261e"), Color("182a42"), Color("231b39")]
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

func _ready() -> void:
    _load_game()
    for i in range(95):
        stars.append(Vector2(float((i * 337 + 67) % 2400), float((i * 149 + 39) % 480)))
    _build_ui()
    _start_level()

func _make_pads() -> Array:
    var shift: float = float(level % 4) * 25.0
    return [
        {"id": 1, "x": 240.0, "y": 600.0, "width": 220.0},
        {"id": 2, "x": 720.0, "y": 470.0 - shift, "width": 220.0},
        {"id": 3, "x": 1250.0, "y": 555.0 + shift, "width": 230.0},
        {"id": 4, "x": 1800.0, "y": 385.0 + shift, "width": 240.0},
        {"id": 5, "x": 2180.0, "y": 585.0, "width": 190.0}
    ]

func _start_level() -> void:
    pads = _make_pads()
    passenger_onboard = false
    fares_in_level = 0
    source_pad = 1
    destination_pad = 3
    mission_done = false
    game_over = false
    if is_instance_valid(taxi):
        taxi.queue_free()
    taxi = TAXI_SCENE.instantiate()
    taxi.position = Vector2(float(pads[0]["x"]), float(pads[0]["y"]) - 21.0)
    taxi.pads = pads
    taxi.world_width = WIDTH
    taxi.floor_height = FLOOR
    taxi.landed_on = 1
    taxi.engine_level = engine_level
    taxi.stabilizer_level = stabilizer_level
    taxi.fuel_capacity = 100.0 + tank_level * 40.0
    taxi.fuel = taxi.fuel_capacity
    add_child(taxi)
    taxi.landed.connect(_on_landed)
    taxi.damaged.connect(_on_damaged)
    if not is_instance_valid(camera):
        camera = Camera2D.new()
        camera.enabled = true
        camera.position_smoothing_enabled = true
        camera.position_smoothing_speed = 4.5
        camera.limit_left = 0
        camera.limit_right = int(WIDTH)
        camera.limit_top = 0
        camera.limit_bottom = 720
        add_child(camera)
    camera.global_position = Vector2(640, 360)
    _announce("SHIFT %d — %s. Pick up at PAD 01." % [level + 1, LEVEL_NAMES[level % LEVEL_NAMES.size()]])
    _refresh_ui()
    queue_redraw()

func _process(dt: float) -> void:
    pulse += dt
    if is_instance_valid(taxi):
        camera.global_position = Vector2(taxi.global_position.x, 360.0)
        fuel_bar.max_value = taxi.fuel_capacity
        fuel_bar.value = taxi.fuel
        hull_bar.value = taxi.hull
        telemetry.text = "CREDITS %d  |  FARES %d  |  SPEED %d / %d  |  LEVEL %d" % [credits, deliveries, int(absf(taxi.velocity.x)), int(absf(taxi.velocity.y)), level + 1]
        if taxi.hull <= 0.0 and not game_over:
            game_over = true
            taxi.input_locked = true
            _announce("TAXI DISABLED. Press R to restart this shift.")
    if message_timer > 0.0:
        message_timer -= dt
    queue_redraw()

func _draw() -> void:
    var bg: Color = LEVEL_COLORS[level % LEVEL_COLORS.size()]
    draw_rect(Rect2(0, 0, WIDTH, 720), bg)
    for star in stars:
        draw_circle(star, 1.0 + fposmod(star.x, 3.0) * 0.25, Color(0.62, 0.78, 0.87, 0.6))
    draw_circle(Vector2(1990, 155), 110, Color(0.16, 0.25, 0.32, 0.9))
    draw_arc(Vector2(1990, 155), 117, 0, TAU, 90, Color(0.38, 0.48, 0.56, 0.65), 3)
    for i in range(16):
        var x: float = float(i) * 160.0
        var h: float = 105.0 + float((i * 57 + level * 31) % 160)
        draw_rect(Rect2(x, FLOOR - h, 112, h), bg.lightened(0.08))
        draw_rect(Rect2(x + 14, FLOOR - h + 24, 7, 25), Color(0.13, 0.40, 0.49, 0.6))
        draw_rect(Rect2(x + 34, FLOOR - h + 24, 7, 25), Color(0.13, 0.40, 0.49, 0.6))
    draw_rect(Rect2(0, FLOOR, WIDTH, 40), Color("283640"))
    draw_rect(Rect2(0, FLOOR, WIDTH, 4), Color("568b98"))
    for pad in pads:
        var px: float = float(pad["x"])
        var py: float = float(pad["y"])
        var pw: float = float(pad["width"])
        draw_rect(Rect2(px - pw * 0.5, py, pw, 25), Color("43515d"))
        draw_rect(Rect2(px - pw * 0.5, py, pw, 5), Color("72cbd7"))
        draw_rect(Rect2(px - 8, py + 25, 16, FLOOR - py - 25), Color("26343d"))
        var label: String = "PAD %02d" % int(pad["id"])
        if int(pad["id"]) == source_pad and not passenger_onboard and not mission_done:
            label += "  PICKUP"
            draw_circle(Vector2(px + 46, py - 15), 8, Color(0.98, 0.79, 0.37, 0.6 + sin(pulse * 5.0) * 0.3))
        elif int(pad["id"]) == destination_pad and passenger_onboard:
            label += "  DROPOFF"
        elif int(pad["id"]) == 2:
            label += "  SERVICE"
        draw_string(ThemeDB.fallback_font, Vector2(px - pw * 0.5 + 8, py - 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("c6eef4"))

func _build_ui() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var box: PanelContainer = PanelContainer.new()
    box.position = Vector2(16, 14)
    box.custom_minimum_size = Vector2(610, 143)
    hud.add_child(box)
    var stack: VBoxContainer = VBoxContainer.new()
    box.add_child(stack)
    var heading: Label = Label.new()
    heading.text = "SPACE TAXI: FRONTIER   //   FLIGHT OPERATIONS"
    heading.add_theme_font_size_override("font_size", 17)
    heading.add_theme_color_override("font_color", Color("78dce9"))
    stack.add_child(heading)
    objective = Label.new()
    objective.add_theme_font_size_override("font_size", 16)
    stack.add_child(objective)
    telemetry = Label.new()
    stack.add_child(telemetry)
    var row: HBoxContainer = HBoxContainer.new()
    stack.add_child(row)
    var fl: Label = Label.new()
    fl.text = "FUEL"
    row.add_child(fl)
    fuel_bar = ProgressBar.new()
    fuel_bar.custom_minimum_size = Vector2(180, 17)
    fuel_bar.show_percentage = false
    row.add_child(fuel_bar)
    var hl: Label = Label.new()
    hl.text = "HULL"
    row.add_child(hl)
    hull_bar = ProgressBar.new()
    hull_bar.custom_minimum_size = Vector2(180, 17)
    hull_bar.show_percentage = false
    row.add_child(hull_bar)
    upgrades = Label.new()
    upgrades.text = "At PAD 02: 1 Engine (400)  |  2 Stabilizers (350)  |  3 Tank (300)  |  4 Repair (75)"
    upgrades.add_theme_font_size_override("font_size", 13)
    stack.add_child(upgrades)
    banner = Label.new()
    banner.position = Vector2(18, 640)
    banner.add_theme_font_size_override("font_size", 18)
    banner.add_theme_color_override("font_color", Color("ffe0a0"))
    hud.add_child(banner)
    controls = Label.new()
    controls.position = Vector2(18, 679)
    controls.text = "A/D or ←/→ STEER  •  W/↑/SPACE LIFT  •  S/↓ BRAKE  •  1–4 SHOP  •  N NEXT SHIFT  •  R RETRY"
    controls.add_theme_font_size_override("font_size", 13)
    hud.add_child(controls)

func _refresh_ui() -> void:
    if mission_done:
        objective.text = "SHIFT COMPLETE — Press N for next location"
    elif passenger_onboard:
        objective.text = "PASSENGER ONBOARD → PAD %02d" % destination_pad
    else:
        objective.text = "COLLECT PASSENGER → PAD %02d" % source_pad

func _announce(text: String) -> void:
    banner.text = text
    message_timer = 6.0

func _on_landed(pad_id: int) -> void:
    if game_over:
        return
    if pad_id == 2:
        taxi.refuel(40.0)
        _announce("Service station: +40 fuel. Buy upgrades with keys 1–4.")
    if mission_done:
        return
    if not passenger_onboard and pad_id == source_pad:
        passenger_onboard = true
        _announce("Passenger aboard! Destination PAD %02d. Fly carefully." % destination_pad)
    elif passenger_onboard and pad_id == destination_pad:
        passenger_onboard = false
        var fare: int = 220 + level * 85 + (fares_in_level * 65)
        credits += fare
        deliveries += 1
        fares_in_level += 1
        _save_game()
        if fares_in_level >= 3:
            mission_done = true
            _announce("SHIFT COMPLETE! Earned %d credits. Press N for next location." % fare)
        else:
            source_pad = destination_pad
            destination_pad = [4, 5, 1][fares_in_level - 1]
            _announce("Fare paid: %d credits! Next passenger at PAD %02d." % [fare, source_pad])
    _refresh_ui()

func _on_damaged(amount: float) -> void:
    _announce("Hard impact: -%d hull. Use brake before touchdown." % int(amount))

func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo:
        return
    if event.physical_keycode == KEY_R:
        _start_level()
    elif event.physical_keycode == KEY_N and mission_done:
        level += 1
        _save_game()
        _start_level()
    elif taxi.landed_on == 2:
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
            taxi.fuel_capacity = 100.0 + tank_level * 40.0
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
    var cfg: ConfigFile = ConfigFile.new()
    cfg.set_value("career", "credits", credits)
    cfg.set_value("career", "deliveries", deliveries)
    cfg.set_value("career", "level", level)
    cfg.set_value("upgrades", "engine", engine_level)
    cfg.set_value("upgrades", "stabilizers", stabilizer_level)
    cfg.set_value("upgrades", "tank", tank_level)
    cfg.save(SAVE_PATH)

func _load_game() -> void:
    var cfg: ConfigFile = ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    credits = int(cfg.get_value("career", "credits", 0))
    deliveries = int(cfg.get_value("career", "deliveries", 0))
    level = int(cfg.get_value("career", "level", 0))
    engine_level = int(cfg.get_value("upgrades", "engine", 0))
    stabilizer_level = int(cfg.get_value("upgrades", "stabilizers", 0))
    tank_level = int(cfg.get_value("upgrades", "tank", 0))
