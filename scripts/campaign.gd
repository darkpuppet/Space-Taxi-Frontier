extends RefCounted
## Twenty authored sectors. Difficulty rises in small, bounded steps.
const STAGES: Array[Dictionary] = [
    {"name": "ORBITAL ACADEMY", "hint": "Learn to brake before touchdown."},
    {"name": "DUST COLONY", "hint": "Fly between the desert terminals and watch passenger patience."},
    {"name": "ICE MOON", "hint": "The first asteroids block the lower flight lane."},
    {"name": "COPPER RIDGE", "hint": "Moving gates require timing your crossing."},
    {"name": "FIRST CONTACT", "hint": "Alien scouts patrol between the terminals."},
    {"name": "NEON CROSSING", "hint": "Crystal travelers join the fares. Watch patrols through the neon rain."},
    {"name": "TWIN HORIZONS", "hint": "Choose between waiting fares under the twin suns."},
    {"name": "ALIEN OUTPOST", "hint": "Electric beams flash on a timer. Cross while dark."},
    {"name": "EVENT HORIZON", "hint": "Violet rings mark a drifting gravity well."},
    {"name": "DRIFTER'S REACH", "hint": "Hunter drones pursue nearby airborne taxis."},
    {"name": "BINARY DUSK", "hint": "Insectoid travelers join the fares. Prioritize impatient riders."},
    {"name": "SCOUT BELT", "hint": "Proximity mines guard the lower approach."},
    {"name": "SINGULARITY ROW", "hint": "Two drifting wells cross the sector."},
    {"name": "CRIMSON TRANSIT", "hint": "Meteors streak across the volcanic shipping lanes."},
    {"name": "FLOATING GARDEN", "hint": "Floating terminals and mines demand precise approaches."},
    {"name": "NIGHT PATROL", "hint": "Robot couriers join the fares. Four scouts patrol the night ocean."},
    {"name": "VIOLET CURRENT", "hint": "Three wells and two drones control the nebula."},
    {"name": "OUTER RIM", "hint": "Narrow station docks demand low lateral speed."},
    {"name": "LAST LIGHT", "hint": "Twin meteor streams cross the eclipse approach."},
    {"name": "FRONTIER'S END", "hint": "Complete the final three fares to finish the campaign."}
]
const PALETTES: Array[Color] = [
    Color("102431"), Color("49302b"), Color("153b50"), Color("3e2b29"),
    Color("183c34"), Color("21182f"), Color("30354a"), Color("20352c"),
    Color("1c132e"), Color("172c40"), Color("392238"), Color("252d35"),
    Color("291d42"), Color("3b202a"), Color("253b38"), Color("111f35"),
    Color("2c1b40"), Color("2d2b2b"), Color("31202f"), Color("20343a")
]
# A level introduces no more than one enemy or obstacle family.
const INTRODUCTIONS: Array[String] = [
    "", "", "asteroids", "gates", "aliens", "", "", "electric_beams",
    "black_holes", "hunter_drones", "", "mines", "", "meteors", "", "", "", "", "", ""
]
const THEMES: Array[String] = [
    "Observation hangar", "Desert mesas", "Ice aurora", "Copper canyon", "Fungal forest",
    "Neon metropolis", "Twin suns", "Alien hive", "Deep-space void", "Orbital wheel",
    "Binary sunset", "Asteroid belt", "Spatial rift", "Volcanic crust", "Floating gardens",
    "Night ocean", "Violet nebula", "Derelict station", "Total eclipse", "Frontier gateway"
]

static func sector(index: int) -> Dictionary:
    var n: int = clampi(index, 0, STAGES.size() - 1)
    var result: Dictionary = STAGES[n].duplicate(true)
    result["index"] = n
    result["theme"] = THEMES[n]
    result["introduces"] = [] if INTRODUCTIONS[n].is_empty() else [INTRODUCTIONS[n]]
    result["asteroids"] = 0 if n < 2 else 1 + int((n - 2) / 8)
    result["gates"] = 0 if n < 3 else 1
    result["wind"] = 0.0
    result["beams"] = 0 if n < 7 else 1
    result["drones"] = 0 if n < 9 else (2 if n >= 16 else 1)
    result["mines"] = 0 if n < 11 else 1 + int((n - 11) / 4)
    result["meteors"] = 0 if n < 13 else (2 if n >= 18 else 1)
    result["color"] = PALETTES[n % PALETTES.size()]
    result["gravity"] = 300.0
    result["planet_strength"] = 0.0
    result["planet_count"] = 0
    result["aliens"] = 0 if n < 4 else 1 + int((n - 4) / 3)
    result["holes"] = 0 if n < 8 else 1 + int((n - 8) / 4)
    result["hazard_speed"] = 0.20 + n * 0.008
    result["landing_horizontal"] = 155.0 - n * 2.0
    result["landing_vertical"] = 225.0 - n * 2.0
    result["fares"] = 3
    # Required cash in hand, after upgrades, repairs, and fines. Level 1: 750 CR;
    # Level 20: 53,000 CR. Extra fares remain available below the target.
    result["required_balance"] = 750 * (n + 1) + 100 * n * (n + 1)
    result["difficulty"] = 1.0 + n * 0.05
    return result

# Layouts live in the corresponding inherited level scenes.
static func level_scene_path(index: int) -> String:
    return "res://levels/level_%02d.tscn" % (clampi(index, 0, STAGES.size() - 1) + 1)

static func pads_for(index: int) -> Array:
    var scene: PackedScene = load(level_scene_path(index))
    var instance: Node = scene.instantiate()
    var result: Array = instance.pad_layout()
    instance.free()
    return result
