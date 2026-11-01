extends SceneTree
const CAMPAIGN = preload("res://scripts/campaign.gd")
const BITMAP = preload("res://scripts/bitmap_art.gd")

func _initialize() -> void:
    call_deferred("_capture")

func _paint(canvas: Node2D) -> void:
    canvas.draw_rect(Rect2(0, 0, 1280, 1160), Color("09131f"))
    for level in range(20):
        var tile := Vector2((level % 4) * 320, (level / 4) * 232)
        var origin: Vector2 = tile + Vector2(16, 42)
        canvas.draw_string(ThemeDB.fallback_font, tile + Vector2(16, 26), "%02d / %s" % [level + 1, CAMPAIGN.STAGES[level]["name"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
        canvas.draw_texture_rect(BITMAP.background(level), Rect2(origin, Vector2(288, 172.8)), false, Color(0.55, 0.65, 0.75))
        for pad in CAMPAIGN.pads_for(level):
            var point: Vector2 = origin + Vector2(pad["x"], pad["y"]) * 0.12
            var color: Color = Color("6ff3ed") if int(pad["id"]) == 2 else Color("ffce72")
            BITMAP.sprite(canvas, level % 3, Rect2(point - Vector2(float(pad["width"]) * 0.06, 0), Vector2(float(pad["width"]) * 0.12, 4)), color)
            canvas.draw_circle(point - Vector2(0, 1), 2, color)
            canvas.draw_string(ThemeDB.fallback_font, point + Vector2(-5, -6), str(pad["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _capture() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(1280, 1160)
    await process_frame
    var canvas := Node2D.new()
    root.add_child(canvas)
    canvas.draw.connect(_paint.bind(canvas))
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/platform-layouts.png")
    canvas.free()
    quit()
