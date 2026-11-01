extends RefCounted
## Atlas regions are trimmed at runtime; the original generated PNG is preserved.
const ATLAS: Texture2D = preload("res://assets/sprites/frontier-atlas-v1.png")
static var frames: Array[Texture2D] = []

static func _ensure() -> void:
    if not frames.is_empty():
        return
    var source: Image = ATLAS.get_image()
    var width: int = source.get_width()
    var height: int = source.get_height()
    # Generated rows have different padding; these cuts preserve raised hands.
    var cuts: Array[float] = [0.0, 0.219, 0.488, 0.727, 1.0]
    for row in range(4):
        for column in range(4):
            var region := Rect2i(column * width / 4, int(cuts[row] * height), width / 4, int(cuts[row + 1] * height) - int(cuts[row] * height))
            var minimum: Vector2i = region.end
            var maximum: Vector2i = region.position - Vector2i.ONE
            for y in range(region.position.y, region.end.y):
                for x in range(region.position.x, region.end.x):
                    if source.get_pixel(x, y).a >= 0.25:
                        minimum.x = mini(minimum.x, x)
                        minimum.y = mini(minimum.y, y)
                        maximum.x = maxi(maximum.x, x)
                        maximum.y = maxi(maximum.y, y)
            var used := Rect2i(minimum - region.position, maximum - minimum + Vector2i.ONE)
            var texture := AtlasTexture.new()
            texture.atlas = ATLAS
            texture.region = Rect2(region.position + used.position, used.size)
            texture.filter_clip = true
            frames.append(texture)

static func ship(canvas: CanvasItem, type: int, rect: Rect2) -> void:
    _ensure()
    canvas.draw_texture_rect(frames[clampi(type, 0, 3)], rect, false)

static func rider(canvas: CanvasItem, foot: Vector2, variant: int, pose: int) -> void:
    _ensure()
    var first: int = 4 + posmod(variant, 3) * 4
    var texture: Texture2D = frames[first + clampi(pose, 0, 3)]
    var scale: float = 42.0 / frames[first].get_height()
    var size: Vector2 = texture.get_size() * scale
    canvas.draw_texture_rect(texture, Rect2(foot - Vector2(size.x * 0.5, size.y), size), false)

const WALK_ATLAS: Texture2D = preload("res://assets/sprites/frontier-walk-v1.png")
static var walk_frames: Array[Texture2D] = []

static func prepare_walk() -> void:
    if not walk_frames.is_empty():
        return
    var source: Image = WALK_ATLAS.get_image()
    # Row boundaries follow the actual transparent gaps in the generated sheet.
    var cuts: Array[float] = [0.0, 0.355, 0.655, 1.0]
    for row in range(3):
        for column in range(4):
            var low := Vector2i(column * source.get_width() / 4, int(cuts[row] * source.get_height()))
            var high := Vector2i((column + 1) * source.get_width() / 4, int(cuts[row + 1] * source.get_height()))
            var minimum: Vector2i = high
            var maximum: Vector2i = low - Vector2i.ONE
            for y in range(low.y, high.y):
                for x in range(low.x, high.x):
                    if source.get_pixel(x, y).a >= 0.25:
                        minimum.x = mini(minimum.x, x)
                        minimum.y = mini(minimum.y, y)
                        maximum.x = maxi(maximum.x, x)
                        maximum.y = maxi(maximum.y, y)
            var texture := AtlasTexture.new()
            texture.atlas = WALK_ATLAS
            texture.region = Rect2(minimum, maximum - minimum + Vector2i.ONE)
            texture.filter_clip = true
            walk_frames.append(texture)

static func walking_rider(canvas: CanvasItem, foot: Vector2, variant: int, clock: float, direction: float) -> void:
    prepare_walk()
    var texture: Texture2D = walk_frames[posmod(variant, 3) * 4 + posmod(int(clock * 8.0), 4)]
    var size: Vector2 = texture.get_size() * (42.0 / texture.get_height())
    canvas.draw_set_transform(foot, 0, Vector2(-1 if direction < 0 else 1, 1))
    canvas.draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y), size), false)
    canvas.draw_set_transform(Vector2.ZERO)

## Two toe taps followed by a brief impatient pause. Only the boot pivots;
## the passenger's body and supporting foot remain anchored to the platform.
static func foot_tap_angle(clock: float) -> float:
    var phase: float = fposmod(clock, 1.05)
    if phase >= 0.42:
        return 0.0
    return -0.28 * absf(sin(phase * PI / 0.21))

static func impatient_rider(canvas: CanvasItem, foot: Vector2, variant: int, clock: float) -> void:
    _ensure()
    var first: int = 4 + posmod(variant, 3) * 4
    var texture: Texture2D = frames[first + 3]
    var pixels: Vector2 = texture.get_size()
    var scale: float = 42.0 / frames[first].get_height()
    var size: Vector2 = pixels * scale
    var origin: Vector2 = foot - Vector2(size.x * 0.5, size.y)
    var boot_x: float = floorf(pixels.x * 0.55)
    var boot_y: float = floorf(pixels.y * 0.84)
    # Draw the upper body and supporting boot from the original impatient pose.
    canvas.draw_texture_rect_region(texture, Rect2(origin, Vector2(size.x, boot_y * scale)), Rect2(0, 0, pixels.x, boot_y))
    canvas.draw_texture_rect_region(texture, Rect2(origin + Vector2(0, boot_y * scale), Vector2(boot_x, pixels.y - boot_y) * scale), Rect2(0, boot_y, boot_x, pixels.y - boot_y))
    # Pivot at the cuff so the boot stays attached as its toe rises.
    var ankle: Vector2 = origin + Vector2(boot_x, boot_y) * scale
    var boot_size: Vector2 = Vector2(pixels.x - boot_x, pixels.y - boot_y) * scale
    canvas.draw_set_transform(ankle, foot_tap_angle(clock))
    canvas.draw_texture_rect_region(texture, Rect2(Vector2.ZERO, boot_size), Rect2(boot_x, boot_y, pixels.x - boot_x, pixels.y - boot_y))
    canvas.draw_set_transform(Vector2.ZERO)
