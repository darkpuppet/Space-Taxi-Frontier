extends RefCounted
## Unlock levels are player-facing (1 through 20). Variant IDs also select art.
const TYPES: Array[Dictionary] = [
    {"name": "Colonist", "unlock": 1, "alien": false},
    {"name": "Scout", "unlock": 1, "alien": true},
    {"name": "Explorer", "unlock": 1, "alien": false},
    {"name": "Crystal traveler", "unlock": 6, "alien": true},
    {"name": "Insectoid traveler", "unlock": 11, "alien": true},
    {"name": "Robot courier", "unlock": 16, "alien": true, "robot": true}
]

static func available_count(level_index: int) -> int:
    var count: int = 0
    for type in TYPES:
        if int(type["unlock"]) <= level_index + 1:
            count += 1
    return count

static func for_fare(level_index: int, fare_id: int) -> int:
    var count: int = available_count(level_index)
    # Guarantee the new character appears on the first fare of its debut level.
    if fare_id == 1 and count > 3 and int(TYPES[count - 1]["unlock"]) == level_index + 1:
        return count - 1
    return posmod(fare_id - 1 + level_index, count)

static func is_alien(variant: int) -> bool:
    return bool(TYPES[clampi(variant, 0, TYPES.size() - 1)]["alien"])

static func is_robot(variant: int) -> bool:
    return bool(TYPES[clampi(variant, 0, TYPES.size() - 1)].get("robot", false))
