extends RefCounted
var path: String = "user://frontier_scores.cfg"
var entries: Array[Dictionary] = []

func load_scores() -> void:
    entries.clear()
    var cfg := ConfigFile.new()
    if cfg.load(path) != OK:
        return
    var saved = cfg.get_value("scores", "entries", [])
    if saved is Array:
        for item in saved:
            if item is Dictionary and item.get("credits") is int and item.get("level") is int and item.get("fares") is int:
                entries.append({"pilot": str(item.get("pilot", "Pilot")).left(16), "credits": item["credits"], "level": clampi(item["level"], 1, 20), "fares": maxi(0, item["fares"]), "complete": bool(item.get("complete", false))})
    _rank()

func record(pilot: String, credits: int, level: int, fares: int, complete: bool) -> void:
    entries.append({"pilot": pilot.strip_edges().left(16) if not pilot.strip_edges().is_empty() else "Pilot", "credits": credits, "level": level, "fares": fares, "complete": complete})
    _rank()
    var cfg := ConfigFile.new()
    cfg.set_value("scores", "entries", entries)
    cfg.save(path)

func _rank() -> void:
    entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if a["credits"] != b["credits"]: return a["credits"] > b["credits"]
        if a["level"] != b["level"]: return a["level"] > b["level"]
        return a["fares"] > b["fares"])
    if entries.size() > 10:
        entries.resize(10)
