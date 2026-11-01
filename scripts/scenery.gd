extends RefCounted
## Every campaign environment is backed by its own painted bitmap.
static func paint(canvas: Node2D, data: Dictionary, _time: float, world_height: float = 720.0) -> void:
    preload("res://scripts/bitmap_art.gd").paint(canvas, int(data.get("index", 0)), Vector2(2400, world_height))
