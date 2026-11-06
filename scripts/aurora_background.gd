extends Sprite2D
## Animates the painted Ice Moon aurora without changing the source PNG.

func _ready() -> void:
    z_index = -10
    centered = false
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var shader_material := ShaderMaterial.new()
    shader_material.shader = preload("res://assets/effects/ice-aurora.gdshader")
    material = shader_material

func configure(level: int, world_size: Vector2, game_time: float, source: Texture2D = null) -> void:
    visible = level == 2
    if visible:
        texture = source if source != null else preload("res://scripts/bitmap_art.gd").background(level)
        scale = world_size / texture.get_size()
        advance(game_time)

func advance(game_time: float) -> void:
    if visible:
        material.set_shader_parameter("aurora_time", game_time)
