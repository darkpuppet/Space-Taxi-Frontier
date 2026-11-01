extends RefCounted
const LIBRARY = preload("res://assets/dialogue/death-insults.tres")
const FALLBACK: String = "Try landing with the taxi still assembled next time."
var rng := RandomNumberGenerator.new()
var bag: Array[String] = []
var previous: String = ""

func _init() -> void:
    rng.randomize()

func choose() -> String:
    if bag.is_empty():
        for phrase in LIBRARY.phrases:
            var line: String = phrase.strip_edges()
            if not line.is_empty() and not bag.has(line):
                bag.append(line)
        if bag.is_empty():
            bag.append(FALLBACK)
        for index in range(bag.size() - 1, 0, -1):
            var other: int = rng.randi_range(0, index)
            var swap: String = bag[index]
            bag[index] = bag[other]
            bag[other] = swap
        if bag.size() > 1 and bag.back() == previous:
            var swap: String = bag[0]
            bag[0] = bag[-1]
            bag[-1] = swap
    previous = bag.pop_back()
    return previous
