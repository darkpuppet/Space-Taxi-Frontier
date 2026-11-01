extends Node
## Synthesized sound and bundled offline CB dispatch voice clips.
const CACHED_MUSIC = preload("res://assets/audio/synth/music-loop.res")
const CACHED_HUMAN_SCREAM = preload("res://assets/audio/synth/scream-human.res")
const CACHED_ALIEN_SCREAM = preload("res://assets/audio/synth/scream-alien.res")
const CACHED_CLUNK = preload("res://assets/audio/synth/clunk.res")
const CACHED_BEAM = preload("res://assets/audio/synth/beam-loop.res")
var engine: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var phase: float = 0.0
var muted: bool = false
var taxi: CharacterBody2D
var screams: Dictionary = {}
var radio: Node
var music: AudioStreamPlayer
var beam_player: AudioStreamPlayer
var impact_players: Array[AudioStreamPlayer] = []
var clunk: AudioStreamWAV
var impact_cooldown: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for bus in ["FrontierMusic", "FrontierEffects", "FrontierVoices"]:
        if AudioServer.get_bus_index(bus) < 0:
            AudioServer.add_bus()
            AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
    engine = AudioStreamPlayer.new()
    var stream := AudioStreamGenerator.new()
    stream.mix_rate = 22050.0
    stream.buffer_length = 0.12
    engine.stream = stream
    engine.volume_db = -22.0
    add_child(engine)
    engine.bus = "FrontierEffects"
    engine.play()
    engine_playback = engine.get_stream_playback()
    music = AudioStreamPlayer.new()
    music.stream = CACHED_MUSIC
    music.volume_db = -27.0
    add_child(music)
    music.bus = "FrontierMusic"
    music.play()
    radio = preload("res://scripts/dispatch_radio.gd").new()
    add_child(radio)
    radio.player.bus = "FrontierVoices"
    screams[false] = CACHED_HUMAN_SCREAM
    screams[true] = CACHED_ALIEN_SCREAM
    clunk = CACHED_CLUNK
    for index in range(4):
        var player := AudioStreamPlayer.new()
        player.process_mode = Node.PROCESS_MODE_PAUSABLE
        player.stream = clunk
        add_child(player)
        player.bus = "FrontierEffects"
        impact_players.append(player)
    beam_player = AudioStreamPlayer.new()
    beam_player.process_mode = Node.PROCESS_MODE_PAUSABLE
    beam_player.stream = CACHED_BEAM
    beam_player.volume_db = -80.0
    add_child(beam_player)
    beam_player.bus = "FrontierEffects"

func apply_volumes(values: Dictionary) -> void:
    for pair in [["Master", "master"], ["FrontierMusic", "music"], ["FrontierEffects", "effects"], ["FrontierVoices", "voices"]]:
        AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]), linear_to_db(maxf(0.00001, float(values[pair[1]]))))

func _process(_dt: float) -> void:
    impact_cooldown = maxf(0, impact_cooldown - _dt)
    _update_beam_audio(_dt)
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
    player.bus = "FrontierEffects"
    player.finished.connect(player.queue_free)
    player.play()

## Speed normal to the surface controls both loudness and the clunk's weight.
func impact(speed: float) -> void:
    if muted or speed < 1.0 or impact_cooldown > 0 or get_tree().paused:
        return
    var strength: float = clampf(speed / 340.0, 0.0, 1.0)
    var player: AudioStreamPlayer = impact_players[0]
    for candidate in impact_players:
        if not candidate.playing:
            player = candidate
            break
    player.volume_db = lerpf(-32.0, -7.0, sqrt(strength))
    player.pitch_scale = lerpf(1.30, 0.78, strength)
    player.play()
    # Suppress solver chatter without tying sound to damage invulnerability.
    impact_cooldown = 0.06

func _update_beam_audio(dt: float) -> void:
    if not is_instance_valid(beam_player) or beam_player.stream == null:
        return
    var strength: float = 0.0
    if is_instance_valid(taxi) and not taxi.input_locked and not taxi.capture_active and taxi.visible and not get_tree().paused and not muted:
        if is_instance_valid(taxi.environment):
            strength = taxi.environment.beam_proximity(taxi.global_position)
    if strength <= 0.001:
        beam_player.stop()
        beam_player.volume_db = -80.0
        return
    var target_db: float = lerpf(-38.0, -13.0, strength)
    if not beam_player.playing:
        beam_player.volume_db = target_db
        beam_player.play()
    else:
        beam_player.volume_db = move_toward(beam_player.volume_db, target_db, dt * 65.0)

## A short noise strike excites several damped, inharmonic hull resonances.
func _clunk_sound() -> AudioStreamWAV:
    var data := PackedByteArray()
    data.resize(8820 * 2)
    var rng := RandomNumberGenerator.new()
    rng.seed = 73917
    var low_noise: float = 0.0
    for i in range(8820):
        var t: float = float(i) / 22050.0
        low_noise = lerpf(low_noise, rng.randf_range(-1, 1), 0.35)
        var strike: float = low_noise * exp(-t * 85) * 0.8
        var body: float = sin(TAU * 112 * t) * exp(-t * 15) * 0.48
        body += sin(TAU * 267 * t) * exp(-t * 23) * 0.23
        body += sin(TAU * 593 * t) * exp(-t * 34) * 0.13
        var sample: float = tanh((strike + body) * 1.6) * minf(t * 2200, 1) * maxf(0, 1 - t / 0.4)
        data.encode_s16(i * 2, int(sample * 29000))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    stream.data = data
    return stream

## A seamless electrical hum with a high sizzling overtone. Proximity controls
## gain; inactive beams and menus never leave an ambient sound playing.
func _beam_loop() -> AudioStreamWAV:
    var data := PackedByteArray()
    data.resize(22050 * 2)
    for i in range(22050):
        var t: float = float(i) / 22050.0
        var pulse: float = 0.78 + 0.22 * sin(TAU * 8 * t)
        var sample: float = sin(TAU * 110 * t) * 0.24 + sin(TAU * 220 * t) * 0.16
        sample += sin(TAU * 880 * t + sin(TAU * 60 * t) * 1.6) * 0.09
        sample += sin(TAU * 1760 * t) * 0.025
        data.encode_s16(i * 2, int(sample * pulse * 29000))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    stream.data = data
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = 22050
    return stream

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
