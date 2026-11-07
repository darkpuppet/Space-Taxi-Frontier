extends Node2D
## Independent scenic planes. Gameplay geometry stays in the main world canvas.
const WORLD = preload("res://scripts/world.gd")
const BITMAP = preload("res://scripts/bitmap_art.gd")
const DEPTH_SHADER = preload("res://assets/effects/scenery-depth.gdshader")
const SLICE_SHADER = preload("res://assets/effects/background-slice.gdshader")
const SKY_SHADER = preload("res://assets/effects/background-sky.gdshader")
const OVERSCAN: float = 96.0
const REFERENCE_CENTER := Vector2(640, 360)

@export var parallax_enabled: bool = true
@export var sky_scroll_scale := Vector2(0.04, 0.025)
@export var animated_scroll_scale := Vector2(0.90, 0.94)
@export var planet_scroll_scale := Vector2(0.97, 0.98)
@export var window_scroll_scale := Vector2(0.99, 0.99)
@export var buildings_scroll_scale := Vector2.ONE
@export_group("Six Depth Layers")
@export var depth_mask: Texture2D
## Repainted RGBA plates in back-to-front order; no semantic extraction.
@export var authored_depth_textures: Array[Texture2D] = []
@export var distant_planet_scroll_scale := Vector2(0.90, 0.94)
@export var middle_planet_scroll_scale := Vector2(0.94, 0.96)
@export var far_landscape_scroll_scale := Vector2(0.97, 0.98)
@export var near_landscape_scroll_scale := Vector2(0.985, 0.99)
@export_group("Layer Sprites")
@export var sky_layer_texture: Texture2D
@export var animated_layer_texture: Texture2D
@export var planet_layer_texture: Texture2D
@export var glass_layer_texture: Texture2D
@export var frame_layer_texture: Texture2D
@export var buildings_layer_texture: Texture2D
@export_group("Artwork Separation")
@export var planets_mask: Texture2D
@export var frame_mask: Texture2D
@export var buildings_mask: Texture2D
@export var planet_reconstruction_texture: Texture2D
@export_group("Window Glass")
@export var window_transparency_mask: Texture2D
@export_range(0.0, 1.0, 0.01) var window_glass_opacity: float = 0.06

var static_sky: Node2D
var twinkling_stars: Node2D
var animated_elements: Node2D
var planet_scenery: Sprite2D
var window_glass: Sprite2D
var window_frame: Sprite2D
var buildings: Sprite2D
var near_landscape: Sprite2D
var observation_glass: Sprite2D
var depth_planes: Array[Sprite2D] = []
var sky_material: ShaderMaterial
var traffic: RefCounted
var aurora: Sprite2D
var level: int = 0
var sky_color := Color("102431")
var stars: Array[Vector2] = []
var sky_texture: Texture2D
var sky_source: Texture2D
var sky_crop: Rect2
var animated_texture: Texture2D
var layer_textures: Dictionary = {}
var rain_layers: Array[Node2D] = []

func _ready() -> void:
    static_sky = Node2D.new()
    static_sky.name = "DistantStarscape"
    static_sky.z_index = -50
    add_child(static_sky)
    static_sky.draw.connect(_paint_sky)
    twinkling_stars = Node2D.new()
    twinkling_stars.name = "TwinklingStars"
    twinkling_stars.z_index = 1
    static_sky.add_child(twinkling_stars)
    twinkling_stars.draw.connect(_paint_twinkles)
    animated_elements = Node2D.new()
    animated_elements.name = "AnimatedBackground"
    animated_elements.z_index = 2
    static_sky.add_child(animated_elements)
    animated_elements.draw.connect(_paint_animated)
    planet_scenery = _make_plane("EarthAndPlanets", -40)
    window_glass = _make_plane("WindowGlass", -30)
    window_frame = _make_plane("WindowFrame", -20)
    buildings = _make_plane("Buildings", -10)
    # Camera smoothing and limits are finalized after normal gameplay processing.
    process_priority = 100

func _make_plane(label: String, depth: int) -> Sprite2D:
    var plane := Sprite2D.new()
    plane.name = label
    plane.z_index = depth
    plane.centered = false
    plane.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(plane)
    return plane

func configure(data: Dictionary, activity: RefCounted, aurora_sprite: Sprite2D, painted_background: Texture2D = null) -> void:
    level = int(data["index"])
    traffic = activity
    aurora = aurora_sprite
    sky_color = data["color"]
    layer_textures.clear()
    # Optional authored plates replace masked legacy art, one sector at a time.
    for layer in ["sky", "animated", "planets", "glass", "frame", "buildings"]:
        var path: String = "res://assets/backgrounds/layers/level-%02d/%s.png" % [level + 1, layer]
        if ResourceLoader.exists(path):
            layer_textures[layer] = load(path)
    var scene_layers: Dictionary = {"sky": sky_layer_texture, "animated": animated_layer_texture, "planets": planet_layer_texture, "glass": glass_layer_texture, "frame": frame_layer_texture, "buildings": buildings_layer_texture}
    for layer in scene_layers:
        if scene_layers[layer] != null:
            layer_textures[layer] = scene_layers[layer]
    sky_texture = layer_textures.get("sky")
    animated_texture = layer_textures.get("animated")
    var source: Texture2D = painted_background if painted_background != null else BITMAP.background(level)
    sky_source = source
    var opening: Rect2 = traffic.SKY_REGIONS[level]
    sky_crop = Rect2(opening.position * source.get_size(), opening.size * source.get_size())
    # Fill the static view with matching open-sky artwork without stretching stars.
    var aspect: float = get_viewport_rect().size.aspect()
    if sky_crop.size.aspect() > aspect:
        var width: float = sky_crop.size.y * aspect
        sky_crop.position.x += (sky_crop.size.x - width) * 0.5
        sky_crop.size.x = width
    else:
        var height: float = sky_crop.size.x / aspect
        sky_crop.position.y += (sky_crop.size.y - height) * 0.5
        sky_crop.size.y = height
    if not authored_depth_textures.is_empty():
        _configure_authored_planes()
    elif depth_mask != null:
        _configure_depth_planes(source)
    else:
        _configure_legacy_planes(source)
    if level == 5 and rain_layers.is_empty():
        for foreground in [false, true]:
            var rain: Node2D = preload("res://scripts/rain_layer.gd").new()
            rain.name = "ForegroundRain" if foreground else "MiddleRain"
            # Middle rain sits behind near scenery; foreground rain crosses the front plate.
            rain.z_index = -19 if foreground else -29
            add_child(rain)
            rain.configure(Vector2(WORLD.WIDTH, WORLD.HEIGHT), foreground)
            rain_layers.append(rain)
    for rain in rain_layers:
        rain.visible = level == 5
    if aurora.get_parent() != animated_elements:
        aurora.reparent(animated_elements, false)
    aurora.z_index = -2
    aurora.material.set_shader_parameter("layer_mask_enabled", true)
    aurora.material.set_shader_parameter("repainted_sky", not authored_depth_textures.is_empty())
    aurora.material.set_shader_parameter("depth_mask_enabled", depth_mask != null)
    if depth_mask != null:
        aurora.material.set_shader_parameter("depth_mask", depth_mask)
    var region: Rect2 = traffic.SKY_REGIONS[level]
    aurora.material.set_shader_parameter("sky_region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
    if not authored_depth_textures.is_empty():
        # Animate only the newly painted sky, never the old solid silhouettes.
        aurora.texture = sky_texture
        aurora.material.set_shader_parameter("depth_mask_enabled", false)
        aurora.material.set_shader_parameter("sky_region", Vector4(0, 0, 1, 1))
    stars.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = 1701 + level * 97
    for index in range(110):
        stars.append(Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)))
    static_sky.queue_redraw()
    twinkling_stars.queue_redraw()
    animated_elements.queue_redraw()
    _process(0)

func _configure_authored_planes() -> void:
    if near_landscape == null:
        near_landscape = _make_plane("NearLandscapeAndBuildings", -20)
    depth_planes.assign([planet_scenery, window_glass, window_frame, near_landscape, buildings])
    var labels := ["DistantPlanets", "MiddleDistancePlanets", "FarLandscapeAndBuildings", "NearLandscapeAndBuildings", "FrontStructures"]
    for index in range(depth_planes.size()):
        var plane: Sprite2D = depth_planes[index]
        plane.name = labels[index]
        plane.z_index = -50 + (index + 1) * 6
        _configure_plane(plane, authored_depth_textures[index], index, false)
        # Equal overscan keeps all plates registered and covers world edges.
        plane.scale = (Vector2(WORLD.WIDTH, WORLD.HEIGHT) + Vector2.ONE * OVERSCAN * 2) / plane.texture.get_size()
        plane.set_meta("base_position", -Vector2.ONE * OVERSCAN)
        plane.visible = true
    if level == 0:
        # Glass is a treatment of the observation frame, not an empty depth slot.
        if observation_glass == null:
            observation_glass = Sprite2D.new()
            observation_glass.name = "ObservationGlass"
            observation_glass.centered = false
            observation_glass.show_behind_parent = true
            var glass_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
            glass_image.fill(Color(0.55, 0.70, 0.80, window_glass_opacity))
            observation_glass.texture = ImageTexture.create_from_image(glass_image)
            near_landscape.add_child(observation_glass)
        observation_glass.scale = near_landscape.texture.get_size()
    static_sky.material = null
    sky_material = null

func _configure_depth_planes(source: Texture2D) -> void:
    if near_landscape == null:
        near_landscape = _make_plane("NearLandscapeAndBuildings", -20)
    # Reuse the legacy nodes so a sector has at most six primary scenic planes.
    depth_planes.assign([planet_scenery, window_glass, window_frame, near_landscape, buildings])
    var labels := ["DistantPlanets", "MiddleDistancePlanets", "FarLandscapeAndBuildings", "NearLandscapeAndBuildings", "FrontStructures"]
    for index in range(depth_planes.size()):
        var plane: Sprite2D = depth_planes[index]
        plane.name = labels[index]
        plane.z_index = -50 + (index + 1) * 6
        _configure_plane(plane, source, index, false)
        plane.scale = (Vector2(WORLD.WIDTH, WORLD.HEIGHT) + Vector2.ONE * OVERSCAN * 2) / source.get_size()
        plane.set_meta("base_position", -Vector2.ONE * OVERSCAN)
        var slice := ShaderMaterial.new()
        slice.shader = SLICE_SHADER
        slice.set_shader_parameter("depth_mask", depth_mask)
        slice.set_shader_parameter("depth_layer", index + 1)
        plane.material = slice
        plane.visible = true
    static_sky.material = null
    if sky_texture == null:
        sky_material = ShaderMaterial.new()
        sky_material.shader = SKY_SHADER
        sky_material.set_shader_parameter("depth_mask", depth_mask)
        var region: Rect2 = traffic.SKY_REGIONS[level]
        sky_material.set_shader_parameter("sky_region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
        static_sky.material = sky_material

func _configure_legacy_planes(source: Texture2D) -> void:
    var separated: bool = planets_mask != null and frame_mask != null and buildings_mask != null and window_transparency_mask != null
    var planet_source: Texture2D = planet_reconstruction_texture if planet_reconstruction_texture != null else source
    _configure_plane(planet_scenery, layer_textures.get("planets", planet_source), 0, not layer_textures.has("planets"))
    _configure_plane(window_glass, layer_textures.get("glass", source), 1, not layer_textures.has("glass"))
    _configure_plane(window_frame, layer_textures.get("frame", source), 2, not layer_textures.has("frame"))
    _configure_plane(buildings, layer_textures.get("buildings", source), 3, not layer_textures.has("buildings"))
    planet_scenery.visible = separated or layer_textures.has("planets")
    window_glass.visible = separated or layer_textures.has("glass")
    window_frame.visible = separated or layer_textures.has("frame")

func _configure_plane(plane: Sprite2D, source: Texture2D, kind: int, masked: bool) -> void:
    plane.texture = source
    plane.material = null
    var margin: float = OVERSCAN if masked else 0.0
    plane.scale = (Vector2(WORLD.WIDTH, WORLD.HEIGHT) + Vector2.ONE * margin * 2) / source.get_size()
    plane.set_meta("base_position", -Vector2.ONE * margin)
    if masked:
        var shader_material := ShaderMaterial.new()
        shader_material.shader = DEPTH_SHADER
        shader_material.set_shader_parameter("layer_kind", kind)
        shader_material.set_shader_parameter("planet_reconstructed", kind == 0 and planet_reconstruction_texture != null)
        if planets_mask != null and frame_mask != null and buildings_mask != null:
            shader_material.set_shader_parameter("semantic_masks_enabled", true)
            shader_material.set_shader_parameter("planets_mask_texture", planets_mask)
            shader_material.set_shader_parameter("frame_mask_texture", frame_mask)
            shader_material.set_shader_parameter("buildings_mask_texture", buildings_mask)
        shader_material.set_shader_parameter("frame_edges", level in [0, 9, 17, 19])
        if window_transparency_mask != null:
            shader_material.set_shader_parameter("window_mask_enabled", true)
            shader_material.set_shader_parameter("window_mask_texture", window_transparency_mask)
            shader_material.set_shader_parameter("glass_opacity", window_glass_opacity)
        var region: Rect2 = traffic.SKY_REGIONS[level]
        shader_material.set_shader_parameter("sky_region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
        plane.material = shader_material

func parallax_offset(camera_center: Vector2, scroll_scale: Vector2) -> Vector2:
    return (camera_center - REFERENCE_CENTER) * (Vector2.ONE - scroll_scale) if parallax_enabled else Vector2.ZERO

func _process(_dt: float) -> void:
    if not is_visible_in_tree():
        return
    var camera: Camera2D = get_viewport().get_camera_2d()
    if not is_instance_valid(camera):
        return
    var center: Vector2 = camera.get_screen_center_position()
    var view_size: Vector2 = get_viewport_rect().size / camera.zoom
    for index in range(rain_layers.size()):
        rain_layers[index].position = parallax_offset(center, Vector2.ONE if index == 1 else middle_planet_scroll_scale)
    static_sky.position = center - view_size * 0.5
    static_sky.scale = Vector2.ONE / camera.zoom
    if parallax_enabled:
        static_sky.position -= (center - REFERENCE_CENTER) * sky_scroll_scale / camera.zoom
    # Cancel the static sky parent's transform so animated sprites retain world coordinates.
    animated_elements.scale = camera.zoom
    animated_elements.global_position = parallax_offset(center, animated_scroll_scale)
    if depth_mask != null or not authored_depth_textures.is_empty():
        var rates := [distant_planet_scroll_scale, middle_planet_scroll_scale, far_landscape_scroll_scale, near_landscape_scroll_scale, buildings_scroll_scale]
        for index in range(depth_planes.size()):
            _place_plane(depth_planes[index], center, rates[index])
        # Aurora and stars share the slowest sky plane behind every solid plane.
        if is_instance_valid(aurora) and aurora.visible:
            aurora.global_position = static_sky.global_position - Vector2.ONE * OVERSCAN * static_sky.global_scale
            aurora.global_scale = static_sky.global_scale * (get_viewport_rect().size + Vector2.ONE * OVERSCAN * 2) / aurora.texture.get_size()
    else:
        _place_plane(planet_scenery, center, planet_scroll_scale)
        _place_plane(window_glass, center, window_scroll_scale)
        _place_plane(window_frame, center, window_scroll_scale)
        _place_plane(buildings, center, buildings_scroll_scale)
    static_sky.queue_redraw()
    twinkling_stars.queue_redraw()
    animated_elements.queue_redraw()

func _place_plane(plane: Sprite2D, center: Vector2, scroll_scale: Vector2) -> void:
    plane.position = Vector2(plane.get_meta("base_position", Vector2.ZERO)) + parallax_offset(center, scroll_scale)

func _paint_sky() -> void:
    var rect := Rect2(-Vector2.ONE * OVERSCAN, get_viewport_rect().size + Vector2.ONE * OVERSCAN * 2)
    # F6 scene previews can draw one frame before the game configures this node.
    if sky_source == null:
        static_sky.draw_rect(rect, sky_color.darkened(0.78))
        return
    if depth_mask != null or not authored_depth_textures.is_empty():
        static_sky.draw_texture_rect(sky_texture if sky_texture != null else sky_source, rect, false)
        if sky_texture != null:
            static_sky.draw_rect(rect, Color(0.015, 0.035, 0.06, 0.14))
        return
    if sky_texture != null:
        static_sky.draw_texture_rect(sky_texture, rect, false)
    else:
        static_sky.draw_rect(rect, sky_color.darkened(0.78))
        if sky_source != null:
            static_sky.draw_texture_rect_region(sky_source, rect, sky_crop)
            static_sky.draw_rect(rect, Color(0.015, 0.035, 0.06, 0.14))
    if sky_texture != null:
        return
    for index in range(stars.size()):
        var alpha: float = 0.25 + float(index % 5) * 0.12
        static_sky.draw_circle(stars[index], 0.7 if index % 4 else 1.2, Color(0.8, 0.88, 1.0, alpha))

func _paint_twinkles() -> void:
    if is_instance_valid(traffic):
        twinkling_stars.draw_set_transform(Vector2.ZERO, 0.0, get_viewport_rect().size / Vector2(WORLD.WIDTH, WORLD.HEIGHT))
        traffic.paint_stars(twinkling_stars)
        twinkling_stars.draw_set_transform(Vector2.ZERO)

func _paint_animated() -> void:
    if animated_texture != null:
        animated_elements.draw_texture_rect(animated_texture, Rect2(Vector2.ZERO, Vector2(WORLD.WIDTH, WORLD.HEIGHT)), false)
    if is_instance_valid(traffic):
        traffic.paint_passers(animated_elements)
