extends SceneTree
## Offline original foley synthesis: no recordings, external assets or runtime DSP.
## Regenerate: godot --headless --path . --script tools/audio/generate-crumple.gd
const SCORE = preload("res://scripts/cab_crumple.gd")
const RATE: int = 48000

func _initialize() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 72193
    var samples := PackedFloat32Array()
    var count: int = int(RATE * SCORE.DURATION)
    samples.resize(count * 2)
    var low_noise: float = 0.0
    var previous: float = 0.0
    var peak: float = 0.001
    for i in range(count):
        var t: float = float(i) / RATE
        var noise: float = rng.randf_range(-1.0, 1.0)
        low_noise = lerpf(low_noise, noise, 0.16)
        var high_noise: float = noise - low_noise
        var left: float = 0.0
        var right: float = 0.0
        for index in range(SCORE.BUCKLE_TIMES.size()):
            var age: float = t - SCORE.BUCKLE_TIMES[index]
            if age < 0.0 or age > 0.29:
                continue
            var weight: float = 1.0 + float(index) * 0.09
            var attack: float = minf(age * 3000.0, 1.0)
            # A hollow can panel snaps down in pitch as its tension gives way.
            var bend: float = age + 0.0015 * (1.0 - exp(-age * 65.0))
            var body: float = 0.0
            var room: float = 0.0
            for mode in [213.0, 487.0, 913.0, 1733.0, 3187.0, 6211.0]:
                var frequency: float = mode / weight
                var decay: float = exp(-age * (18.0 + mode * 0.003))
                body += sin(TAU * frequency * bend) * decay * 0.15
                room += sin(TAU * frequency * bend + 0.17) * decay * 0.14
            # Irregular little fractures follow each primary buckle, with a
            # broadband initial snap and a rough, short sheet-metal scrape.
            var fractures: float = pow(maxf(0.0, sin(age * 213.0 + sin(age * 619.0) * 2.4)), 12.0)
            var scrape: float = high_noise * (exp(-age * 100.0) * 0.65 + fractures * exp(-age * 17.0) * 0.55)
            var thud: float = sin(TAU * 87.0 * bend) * exp(-age * 40.0) * 0.2
            var pan: float = -0.12 if index % 2 == 0 else 0.12
            left += (body + scrape + thud) * attack * (1.0 - pan)
            right += (room + scrape * 0.91 + thud) * attack * (1.0 + pan)
        # A quiet early room reflection gives width without washing out attacks.
        right += previous * 0.06
        previous = left
        samples[i * 2] = left
        samples[i * 2 + 1] = right
        peak = maxf(peak, maxf(absf(left), absf(right)))
    var pcm := PackedByteArray()
    pcm.resize(count * 4)
    for i in range(samples.size()):
        pcm.encode_s16(i * 2, int(samples[i] / peak * 30000.0))
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = RATE
    wav.stereo = true
    wav.data = pcm
    var result: Error = wav.save_to_wav("res://assets/audio/taxi-can-crumple.wav")
    print("Rendered 48 kHz stereo can crumple: ", error_string(result))
    quit(0 if result == OK else 1)
