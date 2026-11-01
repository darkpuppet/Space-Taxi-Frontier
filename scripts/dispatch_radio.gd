extends Node
## Bundled offline voice clips; one transmission per fare, never overlapping.
signal transmission_started(fare_id: int, pad: int)
const VOICE_NAMES: Array[String] = ["male", "female", "robot"]
const PAD_COUNT: int = 5
const CLIPS: Array[Array] = [
    [
        preload("res://assets/audio/cb-male-pad-01-v2.wav"),
        preload("res://assets/audio/cb-male-pad-02-v2.wav"),
        preload("res://assets/audio/cb-male-pad-03-v2.wav"),
        preload("res://assets/audio/cb-male-pad-04-v2.wav"),
        preload("res://assets/audio/cb-male-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/cb-female-pad-01-v2.wav"),
        preload("res://assets/audio/cb-female-pad-02-v2.wav"),
        preload("res://assets/audio/cb-female-pad-03-v2.wav"),
        preload("res://assets/audio/cb-female-pad-04-v2.wav"),
        preload("res://assets/audio/cb-female-pad-05-v2.wav")
    ],
    [
        preload("res://assets/audio/cb-robot-pad-01-v2.wav"),
        preload("res://assets/audio/cb-robot-pad-02-v2.wav"),
        preload("res://assets/audio/cb-robot-pad-03-v2.wav"),
        preload("res://assets/audio/cb-robot-pad-04-v2.wav"),
        preload("res://assets/audio/cb-robot-pad-05-v2.wav")
    ]
]
var voice_rng := RandomNumberGenerator.new()
var voice_index: int = -1
var level_index: int = -1

var player: AudioStreamPlayer
var pending: Array[Dictionary] = []
var announced: Dictionary = {}
var current_id: int = -1
var gap: float = 0.4

func _ready() -> void:
    voice_rng.randomize()
    process_mode = Node.PROCESS_MODE_PAUSABLE
    player = AudioStreamPlayer.new()
    player.volume_db = -5.0
    add_child(player)
    player.finished.connect(_finished)

func sync_fares(waiting: Array, muted: bool = false) -> void:
    var available: Dictionary = {}
    for fare in waiting:
        var id: int = int(fare["id"])
        var pad: int = int(fare["source"])
        available[id] = true
        if not announced.has(id) and pad >= 1 and pad <= PAD_COUNT:
            announced[id] = true
            if not muted:
                pending.append({"id": id, "pad": pad})
    for index in range(pending.size() - 1, -1, -1):
        if not available.has(int(pending[index]["id"])):
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
    current_id = int(call["id"])
    var pad: int = int(call["pad"])
    player.stream = CLIPS[voice_index][pad - 1]
    player.play()
    transmission_started.emit(current_id, pad)

func _finished() -> void:
    current_id = -1
    gap = 0.45

func silence() -> void:
    pending.clear()
    player.stop()
    current_id = -1
    gap = 0.4

func reset() -> void:
    silence()
    announced.clear()

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
