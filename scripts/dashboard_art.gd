extends RefCounted
## Six original dashboard sprites with pixel regions in the source atlas.
const ATLAS = preload("res://assets/sprites/dashboard-1960s-v1.png")
const YELLOW_FASCIA = preload("res://assets/sprites/dashboard-yellow-v1.png")
enum Part { FASCIA, FUEL, DAMAGE, COUNTER, NEEDLE, TRIM }
const REGIONS: Array[Rect2] = [
    Rect2(8, 138, 500, 312),
    Rect2(555, 73, 423, 424),
    Rect2(1066, 73, 422, 424),
    Rect2(8, 661, 498, 225),
    Rect2(528, 719, 473, 107),
    Rect2(1023, 648, 510, 244),
]

static func texture(part: int) -> AtlasTexture:
    var result := AtlasTexture.new()
    result.atlas = YELLOW_FASCIA if part == Part.FASCIA else ATLAS
    result.region = REGIONS[part]
    return result
