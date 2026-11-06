extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func _run() -> void:
    var level: Node = load("res://levels/level_01.tscn").instantiate()
    var scene: Node = level.get_node("Environment")
    level.remove_child(scene)
    var original: Texture2D = level.background_texture
    level.free()
    root.add_child(scene)
    var traffic := preload("res://scripts/background_traffic.gd").new()
    traffic.configure(0)
    var aurora: Sprite2D = preload("res://scripts/aurora_background.gd").new()
    root.add_child(aurora)
    aurora.configure(0, Vector2(2400, 1440), 0.0, original)
    scene.configure({"index": 0, "color": Color("102431")}, traffic, aurora, original)
    check(scene.depth_mask == null and scene.planets_mask == null, "Observation window uses repainted art without masks")
    check(scene.depth_planes.size() == 5, "Moon, Earth, far outposts, frame and deck are separate planes")
    var glass: Sprite2D = scene.observation_glass
    check(absf(glass.texture.get_image().get_pixel(0, 0).a - 0.06) < 0.005, "Window retains six percent glass opacity")
    check(glass.material == null, "Clear glass cannot carry old baked scenery")
    check(glass.get_parent() == scene.near_landscape and glass.show_behind_parent, "Glass renders directly behind its structural frame")
    var camera := Camera2D.new()
    camera.position = Vector2(1100, 650)
    root.add_child(camera)
    await process_frame
    scene._process(0)
    check(glass.get_global_transform().origin.is_equal_approx(scene.near_landscape.get_global_transform().origin), "Window glass remains registered to frame during travel")
    check(scene.depth_planes[1].texture == scene.authored_depth_textures[1], "Repainted complete Earth stays independent from structures")
    check(scene.near_landscape.material == null and scene.buildings.material == null, "Frame and deck render their own clean alpha")
    camera.free()
    scene.free()
    print("Window glass: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
