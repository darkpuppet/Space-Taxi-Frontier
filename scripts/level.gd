@tool
extends "res://scripts/sector.gd"
## Shared level behavior; individual inherited scenes own artwork and pad markers.
@export_range(0, 19) var sector_index: int = 0
@export var background_texture: Texture2D:
    set(value):
        background_texture = value
        if is_node_ready():
            _update_editor_art()
@export var configuration_overrides: Dictionary = {}
var aurora: Sprite2D

func _ready() -> void:
    aurora = get_node("Aurora")
    _update_editor_art()
    if not Engine.is_editor_hint() and get_parent() == get_tree().root:
        call_deferred("_launch_standalone")

func _update_editor_art() -> void:
    var artwork: Sprite2D = get_node("ArtworkPreview")
    artwork.visible = Engine.is_editor_hint()
    artwork.texture = background_texture
    if background_texture != null:
        artwork.scale = Vector2(2400, 1440) / background_texture.get_size()

func configuration() -> Dictionary:
    var data: Dictionary = preload("res://scripts/campaign.gd").sector(sector_index)
    data.merge(configuration_overrides, true)
    data["index"] = sector_index
    return data

func pad_layout() -> Array:
    var result: Array = []
    for marker in get_node("Pads").get_children():
        if not marker.has_method("as_dictionary"):
            continue
        var pad: Dictionary = marker.as_dictionary()
        var point: Vector2 = get_node("Pads").transform * marker.position
        pad["x"] = point.x
        pad["y"] = point.y
        result.append(pad)
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
    return result

func configure(data: Dictionary, authored_pads: Array = []) -> void:
    super.configure(data, pad_layout() if authored_pads.is_empty() else authored_pads)

func _physics_process(dt: float) -> void:
    if not Engine.is_editor_hint():
        super._physics_process(dt)

func _draw() -> void:
    if not Engine.is_editor_hint():
        super._draw()

func _get_configuration_warnings() -> PackedStringArray:
    var warnings := PackedStringArray()
    if background_texture == null:
        warnings.append("Assign this sector's existing background PNG.")
    if has_node("Pads"):
        var layout: Array = pad_layout()
        if layout.size() != 5:
            warnings.append("A campaign level requires five landing-pad markers.")
        else:
            for index in range(5):
                if int(layout[index]["id"]) != index + 1:
                    warnings.append("Landing pad IDs must be unique and run from 1 through 5.")
                    break
    return warnings

func _launch_standalone() -> void:
    # F6 uses the real game shell in an isolated developer session.
    var game: Node = load("res://Main.tscn").instantiate()
    game.start_level_override = sector_index + 1
    get_tree().root.add_child(game)
    get_tree().current_scene = game
    queue_free()
