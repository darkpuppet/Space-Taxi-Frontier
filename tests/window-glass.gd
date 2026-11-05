extends SceneTree
var checks: int = 0
var failures: int = 0
const ORIGINAL = preload("res://assets/backgrounds/level-01-v1.png")
const MASK_PATH: String = "res://assets/backgrounds/layers/level-01/window-mask-v1.png"
const PROFILE: String = "user://frontier_window_glass_test"

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func sample(image: Image, uv: Vector2) -> Color:
    return image.get_pixel(int(uv.x * image.get_width()), int(uv.y * image.get_height()))

func capture(view: SubViewport) -> Image:
    await process_frame
    await RenderingServer.frame_post_draw
    return view.get_texture().get_image()

func _run() -> void:
    var mask: Texture2D = load(MASK_PATH)
    var matte: Image = mask.get_image()
    check(sample(matte, Vector2(0.45, 0.25)).r > 0.95, "Open starfield is transparent in window matte")
    check(sample(matte, Vector2(0.03, 0.50)).r < 0.05, "Window support remains opaque")
    check(sample(matte, Vector2(0.50, 0.95)).r < 0.05, "Station floor remains opaque")
    check(sample(matte, Vector2(0.50, 0.70)).r < 0.05, "Earth remains visible behind the window")
    if DisplayServer.get_name() != "headless":
        var view := SubViewport.new()
        view.size = Vector2i(480, 288)
        view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(view)
        var backdrop := ColorRect.new()
        backdrop.size = Vector2(view.size)
        backdrop.color = Color.RED
        view.add_child(backdrop)
        var artwork := Sprite2D.new()
        artwork.centered = false
        artwork.texture = ORIGINAL
        artwork.scale = Vector2(view.size) / ORIGINAL.get_size()
        var glass := ShaderMaterial.new()
        glass.shader = load("res://assets/effects/scenery-depth.gdshader")
        glass.set_shader_parameter("overscan", 0.0)
        glass.set_shader_parameter("window_mask_enabled", true)
        glass.set_shader_parameter("window_mask_texture", mask)
        glass.set_shader_parameter("glass_opacity", 0.06)
        artwork.material = glass
        view.add_child(artwork)
        var red: Image = await capture(view)
        backdrop.color = Color.GREEN
        var green: Image = await capture(view)
        var red_window: Color = sample(red, Vector2(0.45, 0.25))
        var green_window: Color = sample(green, Vector2(0.45, 0.25))
        check(red_window.r - green_window.r > 0.8 and green_window.g - red_window.g > 0.8, "Underlying layer shines through the glass")
        check(sample(red, Vector2(0.03, 0.50)) == sample(green, Vector2(0.03, 0.50)), "Changing sky cannot bleed through window supports")
        check(sample(red, Vector2(0.50, 0.70)) == sample(green, Vector2(0.50, 0.70)), "Changing sky cannot erase the planet")
        check(sample(red, Vector2(0.50, 0.95)) == sample(green, Vector2(0.50, 0.95)), "Changing sky cannot bleed through station floor")
        backdrop.hide()
        view.transparent_bg = true
        glass.set_shader_parameter("semantic_masks_enabled", true)
        glass.set_shader_parameter("planets_mask_texture", load("res://assets/backgrounds/layers/level-01/planets-mask-v1.png"))
        glass.set_shader_parameter("frame_mask_texture", load("res://assets/backgrounds/layers/level-01/frame-mask-v1.png"))
        glass.set_shader_parameter("buildings_mask_texture", load("res://assets/backgrounds/layers/level-01/buildings-mask-v1.png"))
        glass.set_shader_parameter("layer_kind", 0)
        var planet_image: Image = await capture(view)
        check(sample(planet_image, Vector2(0.50, 0.70)).a > 0.95, "Planet sprite contains Earth pixels")
        check(sample(planet_image, Vector2(0.50, 0.95)).a < 0.05, "Planet sprite excludes buildings and floor")
        check(sample(planet_image, Vector2(0.45, 0.25)).a < 0.05, "Planet sprite excludes the stars")
        glass.set_shader_parameter("layer_kind", 1)
        var glass_image: Image = await capture(view)
        check(absf(sample(glass_image, Vector2(0.50, 0.70)).a - 0.06) < 0.015, "Glass overlays Earth translucently on its own plane")
        check(absf(sample(glass_image, Vector2(0.45, 0.25)).a - 0.06) < 0.015, "Glass overlays stars with the same transparency")
        glass.set_shader_parameter("layer_kind", 2)
        var frame_image: Image = await capture(view)
        check(sample(frame_image, Vector2(0.03, 0.50)).a > 0.95 and sample(frame_image, Vector2(0.50, 0.70)).a < 0.05, "Frame sprite contains structure and excludes Earth")
        glass.set_shader_parameter("layer_kind", 3)
        var buildings_image: Image = await capture(view)
        check(sample(buildings_image, Vector2(0.50, 0.95)).a > 0.95 and sample(buildings_image, Vector2(0.50, 0.70)).a < 0.05, "Buildings sprite contains floor and excludes Earth")
        view.free()
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = PROFILE + ".cfg"
    root.add_child(game)
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    game._process(0)
    check(game.environment_layers.window_transparency_mask == mask, "Level 1 owns its window mask in the scene")
    check(game.environment_layers.window_glass.material.get_shader_parameter("window_mask_enabled"), "Separate glass sprite uses translucent window treatment")
    check(game.environment_layers.buildings.material.get_shader_parameter("window_mask_enabled"), "Buildings cannot reintroduce baked stars")
    check(game.environment_layers.planet_scenery.material.get_shader_parameter("planet_reconstructed"), "Independent Earth sprite fills previously obscured areas")
    if DisplayServer.get_name() != "headless":
        game.camera.position_smoothing_enabled = false
        game.camera.position = Vector2(1100, 650)
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        DirAccess.make_dir_recursive_absolute("res://.development")
        root.get_texture().get_image().save_png("res://.development/level-01-clear-window.png")
    game.level = 1
    game._start_level()
    check(game.environment_layers.window_transparency_mask == null, "Other sectors retain their existing treatment")
    game.audio.shutdown()
    await create_timer(0.2).timeout
    game.free()
    await create_timer(0.2).timeout
    for suffix in [".cfg", "_settings.cfg", "_scores.cfg"]:
        if FileAccess.file_exists(PROFILE + suffix):
            DirAccess.remove_absolute(PROFILE + suffix)
    print("Window glass: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
