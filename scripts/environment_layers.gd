extends Node2D
## Independent scenic planes. Gameplay geometry stays in the main world canvas.
const WORLD = preload("res://scripts/world.gd")
const BITMAP = preload("res://scripts/bitmap_art.gd")
const DEPTH_SHADER = preload("res://assets/effects/scenery-depth.gdshader")
const OVERSCAN: float = 96.0
const REFERENCE_CENTER := Vector2(640, 360)

@export var parallax_enabled: bool = true
@export var animated_scroll_scale := Vector2(0.90, 0.94)
@export var planet_scroll_scale := Vector2(0.97, 0.98)
@export var window_scroll_scale := Vector2(0.99, 0.99)
@export var buildings_scroll_scale := Vector2.ONE
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
var animated_elements: Node2D
var planet_scenery: Sprite2D
var window_glass: Sprite2D
var window_frame: Sprite2D
var buildings: Sprite2D
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

func _ready() -> void:
    static_sky = Node2D.new()
    static_sky.name = "StaticStarscape"
    static_sky.z_index = -50
    add_child(static_sky)
    static_sky.draw.connect(_paint_sky)
    animated_elements = Node2D.new()
    animated_elements.name = "AnimatedBackground"
    animated_elements.z_index = 1
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
    var separated: bool = planets_mask != null and frame_mask != null and buildings_mask != null and window_transparency_mask != null
    var planet_source: Texture2D = planet_reconstruction_texture if planet_reconstruction_texture != null else source
    _configure_plane(planet_scenery, layer_textures.get("planets", planet_source), 0, not layer_textures.has("planets"))
    _configure_plane(window_glass, layer_textures.get("glass", source), 1, not layer_textures.has("glass"))
    _configure_plane(window_frame, layer_textures.get("frame", source), 2, not layer_textures.has("frame"))
    _configure_plane(buildings, layer_textures.get("buildings", source), 3, not layer_textures.has("buildings"))
    planet_scenery.visible = separated or layer_textures.has("planets")
    window_glass.visible = separated or layer_textures.has("glass")
    window_frame.visible = separated or layer_textures.has("frame")
    if aurora.get_parent() != animated_elements:
        aurora.reparent(animated_elements, false)
    aurora.z_index = -1
    aurora.material.set_shader_parameter("layer_mask_enabled", true)
    var region: Rect2 = traffic.SKY_REGIONS[level]
    aurora.material.set_shader_parameter("sky_region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
    stars.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = 1701 + level * 97
    for index in range(110):
        stars.append(Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)))
    static_sky.queue_redraw()
    animated_elements.queue_redraw()
    _process(0)

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
    static_sky.position = center - view_size * 0.5
    static_sky.scale = Vector2.ONE / camera.zoom
    # Cancel the static sky parent's transform so animated sprites retain world coordinates.
    animated_elements.scale = camera.zoom
    animated_elements.global_position = parallax_offset(center, animated_scroll_scale)
    _place_plane(planet_scenery, center, planet_scroll_scale)
    _place_plane(window_glass, center, window_scroll_scale)
    _place_plane(window_frame, center, window_scroll_scale)
    _place_plane(buildings, center, buildings_scroll_scale)
    animated_elements.queue_redraw()

func _place_plane(plane: Sprite2D, center: Vector2, scroll_scale: Vector2) -> void:
    plane.position = Vector2(plane.get_meta("base_position", Vector2.ZERO)) + parallax_offset(center, scroll_scale)

func _paint_sky() -> void:
    var rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
    if sky_texture != null:
        static_sky.draw_texture_rect(sky_texture, rect, false)
        return
    static_sky.draw_rect(rect, sky_color.darkened(0.78))
    if sky_source != null:
        static_sky.draw_texture_rect_region(sky_source, rect, sky_crop)
        static_sky.draw_rect(rect, Color(0.015, 0.035, 0.06, 0.14))
    for index in range(stars.size()):
        var alpha: float = 0.25 + float(index % 5) * 0.12
        static_sky.draw_circle(stars[index], 0.7 if index % 4 else 1.2, Color(0.8, 0.88, 1.0, alpha))

func _paint_animated() -> void:
    if animated_texture != null:
        animated_elements.draw_texture_rect(animated_texture, Rect2(Vector2.ZERO, Vector2(WORLD.WIDTH, WORLD.HEIGHT)), false)
    if is_instance_valid(traffic):
        traffic.paint(animated_elements)
