extends RefCounted
## Sprite coverage for every remaining world object, hull condition, and particle.
enum Hazard { ASTEROID, BARRIER, MINE, METEOR, EMITTER, BEAM, BLACK_HOLE, STAR_GATE, FLOOR }
enum Effect { FIREBALL, SMOKE, SPARK, THRUSTER, GLOW, RING, ACCIDENT, EMBER }
const HAZARDS: Texture2D = preload("res://assets/sprites/frontier-hazards-v1.png")
const EFFECTS: Texture2D = preload("res://assets/sprites/frontier-effects-v1.png")
const DAMAGE: Texture2D = preload("res://assets/sprites/frontier-damage-v1.png")
static var hazard_frames: Array[Texture2D] = []
static var effect_frames: Array[Texture2D] = []
static var damage_frames: Array[Texture2D] = []

static func slice(atlas: Texture2D, columns: int, rows: Array[float], threshold: float = 0.25) -> Array[Texture2D]:
    if preload("res://scripts/atlas_regions.gd").REGIONS.has(atlas.resource_path):
        return preload("res://scripts/atlas_regions.gd").frames_for(atlas)
    var result: Array[Texture2D] = []
    var source: Image = atlas.get_image()
    for row in range(rows.size() - 1):
        for column in range(columns):
            var low := Vector2i(column * source.get_width() / columns, int(rows[row] * source.get_height()))
            var high := Vector2i((column + 1) * source.get_width() / columns, int(rows[row + 1] * source.get_height()))
            var minimum: Vector2i = high
            var maximum: Vector2i = low - Vector2i.ONE
            for y in range(low.y, high.y):
                for x in range(low.x, high.x):
                    if source.get_pixel(x, y).a >= threshold:
                        minimum.x = mini(minimum.x, x)
                        minimum.y = mini(minimum.y, y)
                        maximum.x = maxi(maximum.x, x)
                        maximum.y = maxi(maximum.y, y)
            var texture := AtlasTexture.new()
            texture.atlas = atlas
            texture.region = Rect2(minimum, maximum - minimum + Vector2i.ONE)
            texture.filter_clip = true
            result.append(texture)
    return result

static func crop(atlas: Texture2D, normalized: Rect2) -> Texture2D:
    var texture := AtlasTexture.new()
    texture.atlas = atlas
    texture.region = Rect2(normalized.position * atlas.get_size(), normalized.size * atlas.get_size())
    texture.filter_clip = true
    return texture

static func prepare_hazards() -> void:
    if hazard_frames.is_empty():
        hazard_frames = slice(HAZARDS, 3, [0.0, 0.34, 0.637, 1.0])
        # The generated wide beam and floor extend beyond the nominal cell padding.
        hazard_frames[Hazard.EMITTER] = crop(HAZARDS, Rect2(0.408, 0.383, 0.14, 0.23))
        hazard_frames[Hazard.STAR_GATE] = crop(HAZARDS, Rect2(0.335, 0.638, 0.31, 0.31))
        hazard_frames[Hazard.BEAM] = crop(HAZARDS, Rect2(0.603, 0.455, 0.36, 0.10))
        hazard_frames[Hazard.FLOOR] = crop(HAZARDS, Rect2(0.645, 0.765, 0.32, 0.09))

static func prepare_effects() -> void:
    if effect_frames.is_empty():
        effect_frames = slice(EFFECTS, 4, [0.0, 0.5, 1.0], 0.04)
        # Native radial sprite textures guarantee smooth alpha and a clear ring center.
        effect_frames[Effect.GLOW] = preload("res://assets/effects/soft-glow.tres")
        effect_frames[Effect.RING] = preload("res://assets/effects/shockwave-ring.tres")

static func prepare_damage() -> void:
    if damage_frames.is_empty():
        damage_frames = slice(DAMAGE, 2, [0.0, 0.258, 0.495, 0.74, 1.0])

static func hazard(canvas: CanvasItem, index: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
    prepare_hazards()
    canvas.draw_texture_rect(hazard_frames[index], rect, false, tint)

static func effect(canvas: CanvasItem, index: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
    prepare_effects()
    canvas.draw_texture_rect(effect_frames[index], rect, false, tint)

static func damage_texture(stage: int, braking: bool = false) -> Texture2D:
    prepare_damage()
    return damage_frames[(clampi(stage, 1, 4) - 1) * 2 + (1 if braking else 0)]

static func streak(canvas: CanvasItem, start: Vector2, finish: Vector2, width: float, tint: Color) -> void:
    var motion: Vector2 = finish - start
    canvas.draw_set_transform(start, motion.angle())
    effect(canvas, Effect.SPARK, Rect2(0, -width * 0.5, maxf(motion.length(), 1), width), tint)
    canvas.draw_set_transform(Vector2.ZERO)
