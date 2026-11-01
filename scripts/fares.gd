extends RefCounted
## Waiting riders have independent patience. Dispatch never creates a rider at
## service platforms, the occupied/last-landed pad, or assigned destinations.
var waiting: Array[Dictionary] = []
var active: Dictionary = {}
var pads: Array = []
var level: int = 0
var serial: int = 0
var missed: int = 0
var killed: int = 0
var abducted: int = 0
var spawn_clock: float = 0.0
var max_waiting: int = 1

func configure(index: int, terminals: Array) -> void:
    level = index
    pads = terminals
    waiting.clear()
    active.clear()
    serial = 0
    missed = 0
    killed = 0
    abducted = 0
    spawn_clock = 0.0
    max_waiting = 2 if level >= 2 else 1

func _contains_source(id: int) -> bool:
    for fare in waiting:
        if int(fare["source"]) == id:
            return true
    return false

func at_pad(id: int) -> Dictionary:
    for fare in waiting:
        if int(fare["source"]) == id:
            return fare
    return {}

func refill(excluded_pad: int, position: Vector2) -> void:
    while waiting.size() < max_waiting:
        var candidates: Array[int] = []
        for pad in pads:
            var id: int = int(pad["id"])
            if not pad.get("services", []).is_empty() or id == excluded_pad or _contains_source(id):
                continue
            if not active.is_empty() and id == int(active["destination"]):
                continue
            var reserved: bool = false
            for fare in waiting:
                if id == int(fare["destination"]):
                    reserved = true
            if not reserved:
                candidates.append(id)
        if candidates.is_empty():
            return
        # Early levels favor short pickups; later levels rotate the dispatch.
        var origin: int = candidates[0]
        if level < 2:
            for id in candidates:
                if absf(float(pads[id - 1]["x"]) - position.x) < absf(float(pads[origin - 1]["x"]) - position.x):
                    origin = id
        else:
            origin = candidates[(serial + level) % candidates.size()]
        var destinations: Array[int] = []
        for pad in pads:
            var id: int = int(pad["id"])
            if pad.get("services", []).is_empty() and id != origin and not _contains_source(id):
                destinations.append(id)
        if destinations.is_empty():
            return
        var destination: int = destinations[0]
        if level < 2:
            destination = destinations[serial % mini(2, destinations.size())]
        else:
            destination = destinations[(serial + level + 1) % destinations.size()]
        serial += 1
        var patience: float = maxf(38.0, 75.0 - level * 1.5)
        waiting.append({"id": serial, "source": origin, "destination": destination, "patience": patience, "initial_patience": patience, "variant": preload("res://scripts/passenger_types.gd").for_fare(level, serial)})

func tick(dt: float, excluded_pad: int, position: Vector2) -> Array[int]:
    var departed: Array[int] = []
    for index in range(waiting.size() - 1, -1, -1):
        if waiting[index].get("abducting", false):
            continue
        waiting[index]["patience"] = maxf(0, float(waiting[index]["patience"]) - dt)
        if float(waiting[index]["patience"]) <= 0:
            departed.append(int(waiting[index]["source"]))
            waiting.remove_at(index)
            missed += 1
    if not departed.is_empty():
        spawn_clock = 0.0
        return departed
    spawn_clock += dt
    if spawn_clock >= 4.0:
        spawn_clock = 0.0
        refill(excluded_pad, position)
    return departed

func kill(fare_id: int) -> bool:
    for index in range(waiting.size()):
        if int(waiting[index]["id"]) == fare_id:
            waiting.remove_at(index)
            killed += 1
            spawn_clock = 0.0
            return true
    return false

func abduct(fare_id: int) -> bool:
    for index in range(waiting.size()):
        if int(waiting[index]["id"]) == fare_id:
            waiting.remove_at(index)
            abducted += 1
            spawn_clock = 0.0
            return true
    return false

func board(pad_id: int) -> bool:
    if not active.is_empty():
        return false
    for index in range(waiting.size()):
        if int(waiting[index]["source"]) == pad_id and not waiting[index].get("abducting", false):
            active = waiting[index]
            waiting.remove_at(index)
            return true
    return false

func finish() -> void:
    active.clear()

func suggested(position: Vector2) -> Dictionary:
    var best: Dictionary = {}
    var best_score: float = INF
    for fare in waiting:
        if fare.get("abducting", false):
            continue
        var pickup: Dictionary = pads[int(fare["source"]) - 1]
        var distance: float = absf(float(pickup["x"]) - position.x)
        var vertical: float = absf(float(pickup["y"]) - 21 - position.y)
        var eta: float = distance / 230.0 + vertical / 160.0 + 5.0
        var score: float = float(fare["patience"]) + eta * 1.5
        if float(fare["patience"]) < eta + 8:
            score += 10000.0
        if score < best_score:
            best = fare
            best_score = score
    return best
