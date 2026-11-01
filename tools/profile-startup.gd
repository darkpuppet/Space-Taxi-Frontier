extends SceneTree
## Run graphically to include the first rendered frame and asset slicing.
var checkpoint: int = 0

func _initialize() -> void:
    call_deferred("_run")

func mark(label: String) -> void:
    var now: int = Time.get_ticks_msec()
    print("STARTUP %s: %d ms" % [label, now - checkpoint])
    checkpoint = now

func _run() -> void:
    checkpoint = Time.get_ticks_msec()
    var scene: PackedScene = load("res://Main.tscn")
    mark("load scene and dependencies")
    var game: Node = scene.instantiate()
    if not game.has_method("_new_game"):
        game.free()
        quit(1)
        return
    mark("instantiate scene")
    game.save_file = "user://frontier_startup_profile.cfg"
    root.add_child(game)
    mark("ready (audio, UI, initial sector)")
    load("res://scripts/sprites.gd")._ensure()
    mark("trim original ship/passenger atlas")
    load("res://scripts/bitmap_art.gd").prepare_props()
    mark("trim platform prop atlas")
    load("res://scripts/game_art.gd").prepare_hazards()
    mark("trim hazard atlas")
    load("res://scripts/game_art.gd").prepare_effects()
    mark("trim effects atlas")
    await process_frame
    await RenderingServer.frame_post_draw
    mark("first rendered frame")
    game.audio.shutdown()
    game.free()
    quit()
