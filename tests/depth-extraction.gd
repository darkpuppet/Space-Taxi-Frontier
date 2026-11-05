extends SceneTree
## Validate authored alpha and actual camera-travel rendering across every sector.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func capture(view: SubViewport) -> Image:
    await process_frame
    await RenderingServer.frame_post_draw
    return view.get_texture().get_image()

func _run() -> void:
    var rendered: bool = DisplayServer.get_name() != "headless"
    var view := SubViewport.new()
    view.size = Vector2i(800, 480)
    view.transparent_bg = true
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var preview := Image.create(3200, 2400, false, Image.FORMAT_RGBA8)
    DirAccess.make_dir_recursive_absolute("res://.development/depth-previews")
    for level in range(1, 21):
        var authored: Node = load("res://levels/level_%02d.tscn" % level).instantiate()
        var scene: Node = authored.get_node("Environment")
        authored.remove_child(scene)
        var original: Texture2D = authored.background_texture
        authored.free()
        check(scene.depth_mask == null, "Level %d never extracts scenery through a matte" % level)
        check(scene.authored_depth_textures.size() == 5, "Level %d has all five repainted RGBA plates" % level)
        check(scene.sky_layer_texture != null, "Level %d has continuous sky" % level)
        for texture: Texture2D in scene.authored_depth_textures:
            var pixels := texture.get_image()
            var clear_count: int = 0
            var painted_count: int = 0
            var white_backdrop: int = 0
            var samples: int = 0
            for y in range(0, pixels.get_height(), 8):
                for x in range(0, pixels.get_width(), 8):
                    var color := pixels.get_pixel(x, y)
                    samples += 1
                    clear_count += int(color.a < 0.01)
                    painted_count += int(color.a > 0.1)
                    white_backdrop += int(color.a > 0.1 and minf(color.r, minf(color.g, color.b)) > 0.93)
            check(clear_count > samples / 10, "Level %d solid plates contain real transparent space" % level)
            check(painted_count > 3, "Level %d has visible artwork in every depth plane" % level)
            check(white_backdrop < samples / 10, "Level %d has no broad white generation backdrop" % level)
        var traffic := preload("res://scripts/background_traffic.gd").new()
        traffic.configure(level - 1)
        var aurora: Sprite2D = preload("res://scripts/aurora_background.gd").new()
        view.add_child(aurora)
        aurora.configure(level - 1, Vector2(2400, 1440), 0.0, original)
        view.add_child(scene)
        scene.configure({"index": level - 1, "color": Color("102431")}, traffic, aurora, original)
        for plane: Sprite2D in scene.depth_planes:
            check(plane.material == null, "Level %d renders direct alpha without extraction shaders" % level)
        var camera := Camera2D.new()
        camera.position = Vector2(1200, 720)
        camera.zoom = Vector2.ONE / 3
        view.add_child(camera)
        if rendered:
            var composed := await capture(view)
            preview.blit_rect(composed, Rect2i(Vector2i.ZERO, view.size), Vector2i((level - 1) % 4, (level - 1) / 4) * view.size)
            composed.save_png("res://.development/depth-previews/level-%02d.png" % level)
            for point in [Vector2(700, 400), Vector2(1700, 1100)]:
                camera.zoom = Vector2.ONE
                camera.position = point
                var moved := await capture(view)
                for corner in [Vector2i(0, 0), Vector2i(799, 0), Vector2i(0, 479), Vector2i(799, 479)]:
                    check(moved.get_pixelv(corner).a > 0.99, "Level %d camera movement leaves no uncovered corners" % level)
                moved.save_png("res://.development/depth-previews/level-%02d-travel-%d.png" % [level, int(point.x)])
            # Isolate a real plate and verify its alpha survives GPU rendering.
            var sprite := Sprite2D.new()
            sprite.centered = false
            sprite.texture = scene.authored_depth_textures[4]
            sprite.scale = Vector2(view.size) / sprite.texture.get_size()
            scene.hide()
            camera.enabled = false
            view.canvas_transform = Transform2D.IDENTITY
            view.add_child(sprite)
            var isolated := await capture(view)
            check(isolated.get_pixel(400, 20).a < 0.05 or level in [8, 12, 18], "Level %d isolated foreground cannot reintroduce a sky footprint" % level)
            sprite.free()
        scene.free()
        camera.free()
    if rendered:
        preview.save_png("res://.development/depth-previews/all-levels.png")
    view.free()
    print("Repainted background plates: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
