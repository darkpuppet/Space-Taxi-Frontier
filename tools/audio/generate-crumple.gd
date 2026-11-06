extends SceneTree
## Offline trim of continuous aluminum-can foley. Provenance: sources/README.md.
## Regenerate: godot --headless --path . --script tools/audio/generate-crumple.gd
const SCORE = preload("res://scripts/cab_crumple.gd")
const SOURCE: String = "res://tools/audio/sources/aluminum-can-crunch.wav"
const RATE: int = 48000
const SOURCE_START: float = 0.18

func _initialize() -> void:
    var source: AudioStreamWAV = AudioStreamWAV.load_from_file(SOURCE)
    if source == null or source.format != AudioStreamWAV.FORMAT_16_BITS or not source.stereo or source.mix_rate != RATE:
        push_error("Expected 48 kHz stereo PCM can recording: " + SOURCE)
        quit(1)
        return
    var source_pcm: PackedByteArray = source.data
    var first: int = int(SOURCE_START * RATE)
    var count: int = int(RATE * SCORE.DURATION)
    if (first + count) * 4 > source_pcm.size():
        push_error("Continuous can recording is shorter than the capture")
        quit(1)
        return
    # One uninterrupted take at its original pitch and speed. The main collapse
    # starts at 0.12 s; retain the smaller scrunches and creaks between buckles.
    # Only normalize level and fade the ends to prevent boundary clicks.
    var samples := PackedFloat32Array()
    samples.resize(count * 2)
    var peak: float = 0.001
    for frame in range(count):
        var fade: float = minf(1.0, minf(float(frame) / (RATE * 0.005), float(count - 1 - frame) / (RATE * 0.045)))
        for channel in range(2):
            var sample: float = source_pcm.decode_s16((first + frame) * 4 + channel * 2) / 32768.0 * fade
            samples[frame * 2 + channel] = sample
            peak = maxf(peak, absf(sample))
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
    print("Trimmed continuous aluminum-can crush at original pitch: ", error_string(result))
    quit(0 if result == OK else 1)
