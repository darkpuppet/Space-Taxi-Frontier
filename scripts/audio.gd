extends Node
## Synthesized sound and bundled offline CB dispatch voice clips.
var engine: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var phase: float = 0.0
var muted: bool = false
var taxi: CharacterBody2D
var screams: Dictionary = {}
var radio: Node
var music: AudioStreamPlayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    engine = AudioStreamPlayer.new()
    var stream := AudioStreamGenerator.new()
    stream.mix_rate = 22050.0
    stream.buffer_length = 0.12
    engine.stream = stream
    engine.volume_db = -22.0
    add_child(engine)
    engine.play()
    engine_playback = engine.get_stream_playback()
    music = AudioStreamPlayer.new()
    music.stream = _music_loop()
    music.volume_db = -27.0
    add_child(music)
    music.play()
    radio = preload("res://scripts/dispatch_radio.gd").new()
    add_child(radio)
    _passenger_scream(false)
    _passenger_scream(true)

func _process(_dt: float) -> void:
    var speaking: bool = is_instance_valid(radio) and radio.player.playing and not get_tree().paused
    music.volume_db = move_toward(music.volume_db, -35.0 if speaking else -27.0, _dt * 35.0)
    if not engine_playback:
        return
    var active: bool = is_instance_valid(taxi) and taxi.engine_on and not get_tree().paused
    var strength: float = 1.0 if active else 0.0
    var frequency: float = 65.0
    if active:
        frequency += clampf(-taxi.velocity.y * 0.12, -15.0, 45.0)
    for i in range(engine_playback.get_frames_available()):
        phase = fmod(phase + frequency / 22050.0, 1.0)
        var sample: float = (sin(phase * TAU) * 0.65 + sin(phase * TAU * 2.01) * 0.18 + randf_range(-0.15, 0.15)) * strength
        engine_playback.push_frame(Vector2.ONE * sample)

func toggle_mute() -> bool:
    muted = not muted
    if muted:
        radio.silence()
    AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
    return muted

func cue(kind: String) -> void:
    var notes: Array = [440.0, 660.0]
    match kind:
        "suction": notes = [523.25, 392.0, 293.66, 220.0, 146.83, 73.42]
        "pickup": notes = [392.0, 523.25, 659.25]
        "fare": notes = [523.25, 659.25, 783.99, 1046.5]
        "complete": notes = [392.0, 523.25, 659.25, 783.99, 1046.5, 1318.5]
        "impact": notes = [110.0, 73.42, 49.0]
        "service": notes = [261.63, 329.63, 392.0]
        "land": notes = [130.81, 196.0]
        "low": notes = [220.0, 0.0, 220.0]
    var player := AudioStreamPlayer.new()
    if kind == "explosion":
        player.stream = _explosion_blast()
    elif kind == "squish":
        player.stream = _squish_sound()
    elif kind in ["scream_human", "scream_alien"]:
        player.stream = _passenger_scream(kind == "scream_alien")
        player.pitch_scale = randf_range(0.95, 1.08)
    else:
        player.stream = _tones(notes, 0.10 if kind != "complete" else 0.16)
    player.volume_db = -13.0
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

## Brief vowel-shaped cartoon yelps, cached before gameplay to avoid impact hitches.
func _passenger_scream(alien: bool) -> AudioStreamWAV:
    if screams.has(alien):
        return screams[alien]
    var count: int = 10584 if alien else 9702
    var samples := PackedFloat32Array()
    samples.resize(count)
    var rng := RandomNumberGenerator.new()
    rng.seed = 8329 if alien else 7291
    var voice_phase: float = 0.0
    var peak: float = 0.001
    for i in range(count):
        var t: float = float(i) / 22050.0
        var progress: float = float(i) / (count - 1)
        # A quick rise into an "aaah", followed by a descending comic tail.
        var pitch: float = 300 + sin(progress * PI) * 260 - progress * 100
        pitch += sin(t * TAU * 24) * 12
        if alien:
            pitch = pitch * 1.45 + sin(t * TAU * 38) * 65
        voice_phase = fposmod(voice_phase + pitch / 22050.0, 1.0)
        var vowel: float = 0.0
        for harmonic in range(1, 21):
            var frequency: float = pitch * harmonic
            var formant: float = 0.04 + exp(-pow((frequency - 820) / 210, 2)) * 0.9
            formant += exp(-pow((frequency - 1250) / 260, 2)) * 0.6
            formant += exp(-pow((frequency - 2700) / 420, 2)) * 0.3
            vowel += sin(voice_phase * TAU * harmonic) * formant / pow(float(harmonic), 0.7)
        var envelope: float = minf(t / 0.008, 1.0) * pow(sin(progress * PI), 0.65)
        var sample: float = (vowel + rng.randf_range(-0.025, 0.025)) * envelope
        if alien:
            sample *= 0.8 + sin(t * TAU * 62) * 0.2
        samples[i] = sample
        peak = maxf(peak, absf(sample))
    var data := PackedByteArray()
    data.resize(count * 2)
    for i in range(count):
        data.encode_s16(i * 2, int(samples[i] / peak * 24000))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    stream.data = data
    screams[alien] = stream
    return stream

func _squish_sound() -> AudioStreamWAV:
    var data := PackedByteArray()
    var rng := RandomNumberGenerator.new()
    rng.seed = 77219
    var wet_noise: float = 0.0
    for i in range(7056):
        var t: float = float(i) / 22050.0
        wet_noise = lerpf(wet_noise, rng.randf_range(-1, 1), 0.35)
        var pitch: float = TAU * (48 * t + 180 * (1 - exp(-t * 21)) / 21)
        var slap: float = wet_noise * exp(-t * 23) * 0.75
        var squelch: float = sin(pitch + wet_noise * 2.5) * exp(-t * 12) * 0.6
        var bubble: float = sin(TAU * 105 * t) * exp(-pow((t - 0.085) / 0.028, 2)) * 0.22
        var fade: float = minf(t * 1200, 1) * maxf(0, 1 - t / 0.32)
        var value: int = int(clampf((slap + squelch + bubble) * fade, -1, 1) * 28000)
        data.append(value & 255)
        data.append((value >> 8) & 255)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    stream.data = data
    return stream

func _explosion_blast() -> AudioStreamWAV:
    var data := PackedByteArray()
    var rng := RandomNumberGenerator.new()
    rng.seed = 41967
    var rumble: float = 0.0
    for i in range(26460):
        var t: float = float(i) / 22050.0
        var noise: float = rng.randf_range(-1, 1)
        rumble = lerpf(rumble, noise, 0.12)
        var tail: float = pow(maxf(0, 1.0 - t / 1.2), 2)
        var bass: float = sin(TAU * (36 * t + 160 * (1 - exp(-t * 10)) / 10))
        var sample: float = (noise * exp(-t * 12) * 0.5 + rumble * 1.8 + bass * exp(-t * 4) * 0.6) * tail * minf(1, t * 900)
        var value: int = int(clampf(sample, -1, 1) * 30000)
        data.append(value & 255)
        data.append((value >> 8) & 255)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    stream.data = data
    return stream

func _tones(notes: Array, duration: float) -> AudioStreamWAV:
    var data := PackedByteArray()
    var samples: int = int(22050 * duration)
    for note in notes:
        for i in range(samples):
            var t: float = float(i) / 22050.0
            var envelope: float = minf(t * 90.0, 1.0) * pow(1.0 - float(i) / samples, 2.0)
            var value: int = int(sin(t * float(note) * TAU) * envelope * 20000.0)
            data.append(value & 255)
            data.append((value >> 8) & 255)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    stream.data = data
    return stream

func _music_loop() -> AudioStreamWAV:
    var notes: Array = [130.81, 196.0, 261.63, 329.63, 110.0, 164.81, 220.0, 329.63, 87.31, 130.81, 174.61, 261.63, 98.0, 146.83, 196.0, 293.66]
    var stream: AudioStreamWAV = _tones(notes, 0.32)
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = stream.data.size() / 2
    return stream

func shutdown() -> void:
    if is_instance_valid(radio):
        radio.shutdown()
    for child in get_children():
        if child is AudioStreamPlayer:
            child.stop()
            child.stream = null
    engine_playback = null
    engine.stream = null
    music.stream = null

func _exit_tree() -> void:
    shutdown()
