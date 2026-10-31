extends RefCounted
## Original PNGs stay intact; alpha bounds become runtime atlas regions.
const PROP_ATLAS: Texture2D = preload("res://assets/sprites/frontier-props-v1.png")
static var backgrounds: Dictionary = {}
static var props: Array[Texture2D] = []

static func background(index: int) -> Texture2D:
    index = clampi(index, 0, 19)
    if not backgrounds.has(index):
        backgrounds[index] = load("res://assets/backgrounds/level-%02d-v1.png" % (index + 1))
    return backgrounds[index]

static func paint(canvas: CanvasItem, index: int, size: Vector2) -> void:
    canvas.draw_texture_rect(background(index), Rect2(Vector2.ZERO, size), false)
    # Subtle atmospheric veil keeps foreground traffic and landing lights readable.
    canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.035, 0.06, 0.14))

static func prepare_props() -> void:
    if not props.is_empty():
        return
    var source: Image = PROP_ATLAS.get_image()
    var cuts: Array[float] = [0.0, 0.22, 0.59, 1.0]
    for row in range(3):
        for column in range(3):
            var low := Vector2i(column * source.get_width() / 3, int(cuts[row] * source.get_height()))
            var high := Vector2i((column + 1) * source.get_width() / 3, int(cuts[row + 1] * source.get_height()))
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
            texture.atlas = PROP_ATLAS
            texture.region = Rect2(minimum, maximum - minimum + Vector2i.ONE)
            texture.filter_clip = true
            props.append(texture)

static func sprite(canvas: CanvasItem, index: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
    prepare_props()
    canvas.draw_texture_rect(props[clampi(index, 0, 8)], rect, false, tint)

static func supports(canvas: CanvasItem, x: float, y: float, floor_y: float) -> void:
    var cursor: float = y
    while cursor < floor_y:
        var height: float = minf(80.0, floor_y - cursor)
        sprite(canvas, 6, Rect2(x - 9, cursor, 18, height), Color(0.7, 0.8, 0.9, 0.6))
        cursor += height
