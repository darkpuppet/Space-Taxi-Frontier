extends RefCounted
## Retractable glass lifts exist only for approaching or delivered fares.
const SPRITES = preload("res://scripts/sprites.gd")
const ATLAS: Texture2D = preload("res://assets/sprites/frontier-elevator-v1.png")
# Registered sprite layers: rear cabin, then open/half-closed/closed glass.
const REAR_REGION := Rect2(88, 42, 454, 548)
const DOOR_REGIONS: Array[Rect2] = [Rect2(711, 87, 458, 468), Rect2(97, 691, 434, 484), Rect2(724, 691, 434, 486)]
const WALK_SPEED: float = 72.0
const RISE_TIME: float = 1.0
const CLOSE_TIME: float = 0.6
const DESCEND_TIME: float = 1.4
const CABIN_HEIGHT: float = 70.0
var riders: Array[Dictionary] = []
var expected: Dictionary = {}

func reset() -> void:
    riders.clear()
    expected.clear()

func _target(pad: Dictionary, cab_x: float) -> float:
    var side: float = 1.0 if cab_x <= float(pad["x"]) else -1.0
    return float(pad["x"]) + side * (float(pad["width"]) * 0.5 - 32.0)

func prepare(pad: Dictionary, cab_position: Vector2) -> void:
    # Deploy as the occupied taxi approaches its destination, on its far side.
    if absf(cab_position.x - float(pad["x"])) > float(pad["width"]) * 0.5 + 140.0 or absf(cab_position.y - float(pad["y"])) > 180.0:
        expected.clear()
        return
    var target: float = _target(pad, cab_position.x)
    if int(expected.get("pad", -1)) != int(pad["id"]) or not is_equal_approx(float(expected.get("target", INF)), target):
        expected = {"pad": int(pad["id"]), "target": target, "rise": 0.0}

func drop_off(pad: Dictionary, start_x: float, variant: int) -> void:
    var target: float = _target(pad, start_x)
    var rise: float = 0.0
    if int(expected.get("pad", -1)) == int(pad["id"]) and is_equal_approx(float(expected.get("target", INF)), target):
        rise = float(expected["rise"])
    expected.clear()
    riders.append({"pad": int(pad["id"]), "x": start_x, "target": target,
        "direction": signf(target - start_x), "variant": variant, "clock": 0.0,
        "rise": rise, "age": 0.0, "state": "walking"})

func advance(dt: float) -> void:
    if not expected.is_empty():
        expected["rise"] = minf(1.0, float(expected["rise"]) + dt / RISE_TIME)
    for index in range(riders.size() - 1, -1, -1):
        var rider: Dictionary = riders[index]
        rider["clock"] += dt
        rider["rise"] = minf(1.0, float(rider["rise"]) + dt / RISE_TIME)
        if rider["state"] == "walking":
            rider["x"] = move_toward(float(rider["x"]), float(rider["target"]), WALK_SPEED * dt)
            if is_equal_approx(float(rider["x"]), float(rider["target"])) and float(rider["rise"]) >= 1.0:
                rider["state"] = "closing"
                rider["age"] = 0.0
        else:
            rider["age"] += dt
            if rider["state"] == "closing" and float(rider["age"]) >= CLOSE_TIME:
                rider["state"] = "descending"
                rider["age"] = 0.0
            elif rider["state"] == "descending" and float(rider["age"]) >= DESCEND_TIME:
                riders.remove_at(index)

func lifts_for(pad_id: int) -> Array[Dictionary]:
    var lifts: Array[Dictionary] = []
    if int(expected.get("pad", -1)) == pad_id:
        lifts.append(expected)
    for rider in riders:
        if int(rider["pad"]) == pad_id:
            lifts.append(rider)
    return lifts

func _paint_layer(canvas: CanvasItem, region: Rect2, destination: Rect2, floor_y: float, opacity: float = 1.0) -> void:
    # Clip source pixels at the pad surface, so the artwork rises and retracts
    # without shrinking, stretching, or drawing over the platform below it.
    var visible_height: float = clampf(floor_y - destination.position.y, 0.0, destination.size.y)
    if visible_height <= 0.0 or opacity <= 0.0:
        return
    var source := Rect2(region.position, Vector2(region.size.x, region.size.y * visible_height / destination.size.y))
    var visible := Rect2(destination.position, Vector2(destination.size.x, visible_height))
    canvas.draw_texture_rect_region(ATLAS, visible, source, Color(1.0, 1.0, 1.0, opacity))

func _paint_doors(canvas: CanvasItem, region: Rect2, destination: Rect2, floor_y: float, weight: float) -> void:
    # Keep the painted metal caps solid while allowing the passenger to show
    # through the generated glass. The original atlas alpha stays intact.
    for band in [Vector3(0.0, 0.13, 1.0), Vector3(0.13, 0.90, 0.55), Vector3(0.90, 1.0, 1.0)]:
        var source := Rect2(region.position + Vector2(0.0, region.size.y * band.x), Vector2(region.size.x, region.size.y * (band.y - band.x)))
        var target := Rect2(destination.position + Vector2(0.0, destination.size.y * band.x), Vector2(destination.size.x, destination.size.y * (band.y - band.x)))
        _paint_layer(canvas, source, target, floor_y, weight * band.z)

func _paint_cabin(canvas: CanvasItem, lift: Dictionary, top: float, floor_y: float, offset: float, state: String) -> void:
    var center: float = float(lift["target"])
    # Part of the mechanical base sits inside the landing pad. The rear shell,
    # passenger, and front doors are composited in that order.
    _paint_layer(canvas, REAR_REGION, Rect2(center - 30.0, top, 60.0, 84.0), floor_y)
    if state in ["closing", "descending"]:
        SPRITES.rider_in_lift(canvas, Vector2(center, floor_y - 4.0 + offset), int(lift["variant"]), floor_y)
    var closing: float = clampf(float(lift.get("age", 0.0)) / CLOSE_TIME, 0.0, 1.0) if state == "closing" else (1.0 if state == "descending" else 0.0)
    var pose: float = closing * 2.0
    var first: int = mini(int(pose), 1)
    var blend: float = pose - float(first)
    var doors := Rect2(center - 29.5, top + 7.0, 59.0, 72.0)
    _paint_doors(canvas, DOOR_REGIONS[first], doors, floor_y, 1.0 - blend)
    _paint_doors(canvas, DOOR_REGIONS[first + 1], doors, floor_y, blend)

func paint(canvas: CanvasItem, pad: Dictionary) -> void:
    var floor_y: float = float(pad["y"]) - 2.0
    for lift in lifts_for(int(pad["id"])):
        var center: float = float(lift["target"])
        var state: String = str(lift.get("state", "expected"))
        var descent: float = clampf(float(lift.get("age", 0.0)) / DESCEND_TIME, 0.0, 1.0) if state == "descending" else 0.0
        var rise: float = smoothstep(0.0, 1.0, float(lift["rise"]))
        var offset: float = CABIN_HEIGHT * (1.0 - rise + smoothstep(0.0, 1.0, descent))
        var top: float = floor_y - CABIN_HEIGHT + offset
        var height: float = maxf(0.0, floor_y - top)
        if height > 0.0:
            _paint_cabin(canvas, lift, top, floor_y, offset, state)
        if state == "walking":
            var distance_to_lift: float = absf(float(lift["x"]) - center)
            var step_up: float = 4.0 * clampf(1.0 - distance_to_lift / 12.0, 0.0, 1.0)
            var foot := Vector2(float(lift["x"]), floor_y - step_up)
            if is_equal_approx(float(lift["x"]), center):
                SPRITES.rider(canvas, foot, int(lift["variant"]), 0)
            else:
                SPRITES.walking_rider(canvas, foot, int(lift["variant"]), float(lift["clock"]), float(lift["direction"]))
