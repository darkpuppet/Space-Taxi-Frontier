extends SceneTree
var failures: int = 0
var checks: int = 0

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var regions = load("res://scripts/atlas_regions.gd")
    for path in regions.REGIONS:
        check(FileAccess.get_sha256(path) == regions.SOURCE_HASHES[path], "Atlas crop cache matches the current source image: " + path)
        var atlas: Texture2D = load(path)
        var frames: Array[Texture2D] = regions.frames_for(atlas)
        for frame in frames:
            var rect: Rect2 = frame.region
            check(rect.size.x > 0 and rect.size.y > 0 and Rect2(Vector2.ZERO, atlas.get_size()).encloses(rect), "Cached frame has valid source bounds")
    var source: Node = load("res://scripts/audio.gd").new()
    var regenerated: Dictionary = {
        "music-loop": source._music_loop(), "scream-human": source._passenger_scream(false),
        "scream-alien": source._passenger_scream(true), "clunk": source._clunk_sound(), "beam-loop": source._beam_loop()
    }
    for name in regenerated:
        var cached: AudioStreamWAV = load("res://assets/audio/synth/%s.res" % name)
        var fresh: AudioStreamWAV = regenerated[name]
        check(cached.data == fresh.data and cached.mix_rate == fresh.mix_rate and cached.format == fresh.format, "Cached audio is sample-identical: " + name)
        check(cached.loop_mode == fresh.loop_mode and cached.loop_begin == fresh.loop_begin and cached.loop_end == fresh.loop_end, "Audio cache preserves loop points: " + name)
    source.free()
    print("Startup asset caches: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
