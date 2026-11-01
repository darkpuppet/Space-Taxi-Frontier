extends Node
## Bundled offline voice clips; one transmission per fare, never overlapping.
signal transmission_started(fare_id: int, pad: int)
signal destination_transmission_started(fare_id: int, pad: int, voice: int)
signal gate_transmission_started
const VOICE_NAMES: Array[String] = ["male", "female", "robot"]
const PAD_COUNT: int = 5
const PHRASE_COUNT: int = 6
const CLIPS: Array[Array] = [
    [
        [
            preload("res://assets/audio/cb-male-pickup-phrase-01-pad-01-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-01-pad-02-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-01-pad-03-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-01-pad-04-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-01-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-male-pickup-phrase-02-pad-01-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-02-pad-02-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-02-pad-03-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-02-pad-04-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-02-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-male-pickup-phrase-03-pad-01-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-03-pad-02-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-03-pad-03-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-03-pad-04-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-03-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-male-pickup-phrase-04-pad-01-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-04-pad-02-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-04-pad-03-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-04-pad-04-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-04-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-male-pickup-phrase-05-pad-01-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-05-pad-02-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-05-pad-03-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-05-pad-04-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-05-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-male-pickup-phrase-06-pad-01-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-06-pad-02-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-06-pad-03-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-06-pad-04-v3.wav"),
            preload("res://assets/audio/cb-male-pickup-phrase-06-pad-05-v3.wav")
        ]
    ],
    [
        [
            preload("res://assets/audio/cb-female-pickup-phrase-01-pad-01-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-01-pad-02-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-01-pad-03-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-01-pad-04-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-01-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-female-pickup-phrase-02-pad-01-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-02-pad-02-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-02-pad-03-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-02-pad-04-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-02-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-female-pickup-phrase-03-pad-01-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-03-pad-02-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-03-pad-03-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-03-pad-04-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-03-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-female-pickup-phrase-04-pad-01-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-04-pad-02-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-04-pad-03-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-04-pad-04-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-04-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-female-pickup-phrase-05-pad-01-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-05-pad-02-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-05-pad-03-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-05-pad-04-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-05-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-female-pickup-phrase-06-pad-01-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-06-pad-02-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-06-pad-03-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-06-pad-04-v3.wav"),
            preload("res://assets/audio/cb-female-pickup-phrase-06-pad-05-v3.wav")
        ]
    ],
    [
        [
            preload("res://assets/audio/cb-robot-pickup-phrase-01-pad-01-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-01-pad-02-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-01-pad-03-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-01-pad-04-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-01-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-robot-pickup-phrase-02-pad-01-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-02-pad-02-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-02-pad-03-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-02-pad-04-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-02-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-robot-pickup-phrase-03-pad-01-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-03-pad-02-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-03-pad-03-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-03-pad-04-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-03-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-robot-pickup-phrase-04-pad-01-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-04-pad-02-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-04-pad-03-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-04-pad-04-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-04-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-robot-pickup-phrase-05-pad-01-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-05-pad-02-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-05-pad-03-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-05-pad-04-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-05-pad-05-v3.wav")
        ],
        [
            preload("res://assets/audio/cb-robot-pickup-phrase-06-pad-01-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-06-pad-02-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-06-pad-03-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-06-pad-04-v3.wav"),
            preload("res://assets/audio/cb-robot-pickup-phrase-06-pad-05-v3.wav")
        ]
    ]
]
const GATE_CLIPS: Array[AudioStream] = [
    preload("res://assets/audio/cb-male-stargate-v2.wav"),
    preload("res://assets/audio/cb-female-stargate-v2.wav"),
    preload("res://assets/audio/cb-robot-stargate-v2.wav")
]
const CUSTOMER_VOICES_PER_SPECIES: int = 6
const ROBOT_CUSTOMER_VOICE: int = 12
const DESTINATION_CLIPS: Array[Array] = [
    [
        preload("res://assets/audio/customer-human-1-pad-01-v2.wav"),
        preload("res://assets/audio/customer-human-1-pad-02-v2.wav"),
        preload("res://assets/audio/customer-human-1-pad-03-v2.wav"),
        preload("res://assets/audio/customer-human-1-pad-04-v2.wav"),
        preload("res://assets/audio/customer-human-1-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-human-2-pad-01-v2.wav"),
        preload("res://assets/audio/customer-human-2-pad-02-v2.wav"),
        preload("res://assets/audio/customer-human-2-pad-03-v2.wav"),
        preload("res://assets/audio/customer-human-2-pad-04-v2.wav"),
        preload("res://assets/audio/customer-human-2-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-human-3-pad-01-v2.wav"),
        preload("res://assets/audio/customer-human-3-pad-02-v2.wav"),
        preload("res://assets/audio/customer-human-3-pad-03-v2.wav"),
        preload("res://assets/audio/customer-human-3-pad-04-v2.wav"),
        preload("res://assets/audio/customer-human-3-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-human-4-pad-01-v2.wav"),
        preload("res://assets/audio/customer-human-4-pad-02-v2.wav"),
        preload("res://assets/audio/customer-human-4-pad-03-v2.wav"),
        preload("res://assets/audio/customer-human-4-pad-04-v2.wav"),
        preload("res://assets/audio/customer-human-4-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-human-5-pad-01-v2.wav"),
        preload("res://assets/audio/customer-human-5-pad-02-v2.wav"),
        preload("res://assets/audio/customer-human-5-pad-03-v2.wav"),
        preload("res://assets/audio/customer-human-5-pad-04-v2.wav"),
        preload("res://assets/audio/customer-human-5-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-human-6-pad-01-v2.wav"),
        preload("res://assets/audio/customer-human-6-pad-02-v2.wav"),
        preload("res://assets/audio/customer-human-6-pad-03-v2.wav"),
        preload("res://assets/audio/customer-human-6-pad-04-v2.wav"),
        preload("res://assets/audio/customer-human-6-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-alien-1-pad-01-v2.wav"),
        preload("res://assets/audio/customer-alien-1-pad-02-v2.wav"),
        preload("res://assets/audio/customer-alien-1-pad-03-v2.wav"),
        preload("res://assets/audio/customer-alien-1-pad-04-v2.wav"),
        preload("res://assets/audio/customer-alien-1-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-alien-2-pad-01-v2.wav"),
        preload("res://assets/audio/customer-alien-2-pad-02-v2.wav"),
        preload("res://assets/audio/customer-alien-2-pad-03-v2.wav"),
        preload("res://assets/audio/customer-alien-2-pad-04-v2.wav"),
        preload("res://assets/audio/customer-alien-2-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-alien-3-pad-01-v2.wav"),
        preload("res://assets/audio/customer-alien-3-pad-02-v2.wav"),
        preload("res://assets/audio/customer-alien-3-pad-03-v2.wav"),
        preload("res://assets/audio/customer-alien-3-pad-04-v2.wav"),
        preload("res://assets/audio/customer-alien-3-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-alien-4-pad-01-v2.wav"),
        preload("res://assets/audio/customer-alien-4-pad-02-v2.wav"),
        preload("res://assets/audio/customer-alien-4-pad-03-v2.wav"),
        preload("res://assets/audio/customer-alien-4-pad-04-v2.wav"),
        preload("res://assets/audio/customer-alien-4-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-alien-5-pad-01-v2.wav"),
        preload("res://assets/audio/customer-alien-5-pad-02-v2.wav"),
        preload("res://assets/audio/customer-alien-5-pad-03-v2.wav"),
        preload("res://assets/audio/customer-alien-5-pad-04-v2.wav"),
        preload("res://assets/audio/customer-alien-5-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-alien-6-pad-01-v2.wav"),
        preload("res://assets/audio/customer-alien-6-pad-02-v2.wav"),
        preload("res://assets/audio/customer-alien-6-pad-03-v2.wav"),
        preload("res://assets/audio/customer-alien-6-pad-04-v2.wav"),
        preload("res://assets/audio/customer-alien-6-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/customer-robot-pad-01-v2.wav"),
        preload("res://assets/audio/customer-robot-pad-02-v2.wav"),
        preload("res://assets/audio/customer-robot-pad-03-v2.wav"),
        preload("res://assets/audio/customer-robot-pad-04-v2.wav"),
        preload("res://assets/audio/customer-robot-pad-05-v2.wav")
    ]
]
var spoken_destinations: Dictionary = {}
var gate_announced: bool = false
var voice_rng := RandomNumberGenerator.new()
var customer_rng := RandomNumberGenerator.new()
var customer_bags: Dictionary = {}
var last_customer_voice: Dictionary = {}
var phrase_rng := RandomNumberGenerator.new()
var phrase_bag: Array[int] = []
var last_phrase: int = -1
var current_phrase: int = -1
var voice_index: int = -1
var level_index: int = -1

var player: AudioStreamPlayer
var pending: Array[Dictionary] = []
var announced: Dictionary = {}
var current_pad: int = 0
var current_id: int = -1
var gap: float = 0.4

func _ready() -> void:
    voice_rng.randomize()
    phrase_rng.randomize()
    customer_rng.randomize()
    process_mode = Node.PROCESS_MODE_PAUSABLE
    player = AudioStreamPlayer.new()
    player.volume_db = -5.0
    add_child(player)
    player.finished.connect(_finished)

func sync_fares(waiting: Array, muted: bool = false) -> void:
    if gate_announced:
        if muted:
            silence()
        return
    var available: Dictionary = {}
    for fare in waiting:
        var id: int = int(fare["id"])
        var pad: int = int(fare["source"])
        available[id] = true
        if not announced.has(id) and pad >= 1 and pad <= PAD_COUNT:
            announced[id] = true
            if not muted:
                pending.append({"id": id, "pad": pad, "phrase": _choose_pickup_phrase()})
    for index in range(pending.size() - 1, -1, -1):
        if pending[index].get("kind", "pickup") == "pickup" and not available.has(int(pending[index]["id"])):
            pending.remove_at(index)
    if current_id != -1 and not available.has(current_id):
        player.stop()
        _finished()
    if muted:
        silence()

func _process(dt: float) -> void:
    if player.playing:
        return
    gap = maxf(0, gap - dt)
    if gap > 0 or pending.is_empty() or voice_index < 0:
        return
    var call: Dictionary = pending.pop_front()
    if call.get("kind", "pickup") == "gate":
        player.stream = GATE_CLIPS[voice_index]
        player.play()
        gate_transmission_started.emit()
        return
    if call.get("kind", "pickup") == "destination":
        var pad: int = int(call["pad"])
        var voice: int = int(call["voice"])
        player.stream = DESTINATION_CLIPS[voice][pad - 1]
        player.play()
        destination_transmission_started.emit(int(call["id"]), pad, voice)
        return
    current_id = int(call["id"])
    var pad: int = int(call["pad"])
    current_pad = pad
    current_phrase = int(call["phrase"])
    player.stream = CLIPS[voice_index][current_phrase][pad - 1]
    player.play()
    transmission_started.emit(current_id, pad)

func _finished() -> void:
    current_phrase = -1
    current_pad = 0
    current_id = -1
    gap = 0.45

func silence() -> void:
    current_phrase = -1
    pending.clear()
    player.stop()
    current_pad = 0
    current_id = -1
    gap = 0.4

func reset() -> void:
    gate_announced = false
    silence()
    announced.clear()
    phrase_bag.clear()
    last_phrase = -1
    spoken_destinations.clear()

func shutdown() -> void:
    silence()
    player.stream = null


## Retries keep the same dispatcher; a different level gets a fresh random draw.
func begin_level(index: int) -> void:
    reset()
    if level_index != index:
        level_index = index
        voice_index = voice_rng.randi_range(0, VOICE_NAMES.size() - 1)

func reset_campaign() -> void:
    reset()
    level_index = -1
    voice_index = -1

## Gate calls replace obsolete pickups and use the same level dispatcher.
func announce_gate(muted: bool = false) -> void:
    if gate_announced:
        return
    gate_announced = true
    silence()
    if not muted and voice_index >= 0:
        pending.append({"kind": "gate"})
        gap = 0.15

## Passenger requests take priority over pickups. Each species has six voices.
## Robot couriers have their own voice; other riders draw from species pools.
func announce_destination(fare_id: int, pad: int, variant: int, muted: bool = false) -> void:
    if gate_announced or pad < 1 or pad > PAD_COUNT or spoken_destinations.has(fare_id):
        return
    spoken_destinations[fare_id] = true
    if muted:
        silence()
        return
    var remaining: Array[Dictionary] = pending.duplicate()
    if player.playing and current_id > 0 and current_id != fare_id:
        remaining.push_front({"id": current_id, "pad": current_pad, "phrase": current_phrase})
    silence()
    var types = preload("res://scripts/passenger_types.gd")
    var voice: int = ROBOT_CUSTOMER_VOICE if types.is_robot(variant) else _choose_customer_voice(types.is_alien(variant))
    pending.append({"kind": "destination", "id": fare_id, "pad": pad, "voice": voice})
    for call in remaining:
        if call.get("kind", "pickup") != "pickup" or int(call["id"]) != fare_id:
            pending.append(call)
    gap = 0.1

## Draw every voice once before refilling, with no repeat across bag boundaries.
## Separate pools keep aliens and humans varied without affecting dispatch RNG.
func _choose_customer_voice(alien: bool) -> int:
    var bag: Array = customer_bags.get(alien, [])
    if bag.is_empty():
        var offset: int = CUSTOMER_VOICES_PER_SPECIES if alien else 0
        for index in range(CUSTOMER_VOICES_PER_SPECIES):
            bag.append(offset + index)
        for index in range(bag.size() - 1, 0, -1):
            var other: int = customer_rng.randi_range(0, index)
            var swap: int = bag[index]
            bag[index] = bag[other]
            bag[other] = swap
        if bag.back() == last_customer_voice.get(alien, -1):
            var swap: int = bag[0]
            bag[0] = bag[-1]
            bag[-1] = swap
    var selected: int = bag.pop_back()
    customer_bags[alien] = bag
    last_customer_voice[alien] = selected
    return selected

## Randomize complete sets of six phrases, avoiding repeats between sets.
## The phrase is attached to the fare so interruption never rerolls its wording.
func _choose_pickup_phrase() -> int:
    if phrase_bag.is_empty():
        for index in range(PHRASE_COUNT):
            phrase_bag.append(index)
        for index in range(PHRASE_COUNT - 1, 0, -1):
            var other: int = phrase_rng.randi_range(0, index)
            var swap: int = phrase_bag[index]
            phrase_bag[index] = phrase_bag[other]
            phrase_bag[other] = swap
        if phrase_bag.back() == last_phrase:
            var swap: int = phrase_bag[0]
            phrase_bag[0] = phrase_bag[-1]
            phrase_bag[-1] = swap
    var chosen: int = phrase_bag.pop_back()
    last_phrase = chosen
    return chosen
