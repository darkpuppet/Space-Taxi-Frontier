extends SceneTree
## Offline edit of recorded aluminum-can foley. Provenance: sources/README.md.
## Regenerate: godot --headless --path . --script tools/audio/generate-crumple.gd
const SCORE = preload("res://scripts/cab_crumple.gd")
const SOURCE: String = "res://tools/audio/sources/aluminum-can-crunch.wav"
const RATE: int = 48000

func _initialize() -> void:
    # Read PCM directly so editor import compression cannot affect edits.
    var source: AudioStreamWAV = AudioStreamWAV.load_from_file(SOURCE)
    if source == null or source.format != AudioStreamWAV.FORMAT_16_BITS or not source.stereo:
        push_error("Expected stereo PCM can recording: " + SOURCE)
        quit(1)
        return
    var source_pcm: PackedByteArray = source.data
    var source_frames: int = source_pcm.size() / 4
    var samples := PackedFloat32Array()
    var count: int = int(RATE * SCORE.DURATION)
    samples.resize(count * 2)
    # Keep real panel snaps and crackling intact. Shortening gaps and small pitch
    # variations build from a slow squeeze to a frantic final crushing flurry.
    var pitches: Array[float] = [0.94, 1.02, 0.98, 1.06, 1.10, 1.14]
    var gains: Array[float] = [0.80, 0.88, 0.94, 1.0, 1.03, 1.08]
    for index in range(SCORE.BUCKLE_TIMES.size()):
        var start: int = int(SCORE.BUCKLE_TIMES[index] * RATE)
        var pitch: float = pitches[index]
        var length: int = int(0.245 * RATE / pitch)
        for frame in range(length):
            var at: float = float(frame) / RATE * source.mix_rate * pitch
            var first: int = int(at)
            if first + 1 >= source_frames or start + frame >= count:
                break
            var fraction: float = at - first
            var fade: float = minf(1.0, minf(float(frame) / 48.0, float(length - frame) / 480.0))
            for channel in range(2):
                var a: float = source_pcm.decode_s16(first * 4 + channel * 2) / 32768.0
                var b: float = source_pcm.decode_s16((first + 1) * 4 + channel * 2) / 32768.0
                samples[(start + frame) * 2 + channel] += lerpf(a, b, fraction) * gains[index] * fade
    var peak: float = 0.001
    for value in samples:
        peak = maxf(peak, absf(value))
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
    print("Edited recorded aluminum can into synchronized 48 kHz stereo WAV: ", error_string(result))
    quit(0 if result == OK else 1)
