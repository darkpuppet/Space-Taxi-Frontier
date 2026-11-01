extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    DirAccess.make_dir_recursive_absolute("res://assets/audio/synth")
    var source: Node = load("res://scripts/audio.gd").new()
    source.screams.clear()
    var clips: Dictionary = {
        "music-loop": source._music_loop(),
        "scream-human": source._passenger_scream(false),
        "scream-alien": source._passenger_scream(true),
        "clunk": source._clunk_sound(),
        "beam-loop": source._beam_loop()
    }
    for name in clips:
        var result: int = ResourceSaver.save(clips[name], "res://assets/audio/synth/%s.res" % name, ResourceSaver.FLAG_COMPRESS)
        if result != OK:
            push_error("Could not cache audio: " + str(name))
            source.free()
            quit(1)
            return
        print("Cached synthesized audio: ", name)
    source.free()
    quit()
