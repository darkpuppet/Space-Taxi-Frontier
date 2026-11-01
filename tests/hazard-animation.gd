extends SceneTree
const SECTOR = preload("res://scripts/sector.gd")
const CAMPAIGN = preload("res://scripts/campaign.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(640, 320)
    await process_frame
    var sector := SECTOR.new()
    root.add_child(sector)
    sector.configure(CAMPAIGN.sector(2))
    sector.set_physics_process(false)
    sector.asteroids[0]["position"] = Vector2(160, 160)
    var images: Array[Image] = []
    for time in [0.0, 1.5]:
        sector.elapsed = time
        sector.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        images.append(root.get_texture().get_image())
        var hit: Dictionary = sector.resolve_motion(Vector2(60, 160), Vector2(260, 160), Vector2(200, 0), 10)
        check(hit.get("collided", false) and Vector2(hit["velocity"]).x < 0, "Spinning asteroid remains solid and bounces the taxi")
        check(Vector2(hit["position"]).distance_to(Vector2(121.5, 160)) < 0.01, "Rotation keeps the collision boundary aligned and stable")
    var changed: int = 0
    for y in range(125, 195):
        for x in range(125, 195):
            if images[0].get_pixel(x, y) != images[1].get_pixel(x, y):
                changed += 1
    check(changed > 300, "Foreground rock and warning lights visibly animate")
    check(sector.field_at(Vector2(100, 160)) == Vector2.ZERO, "Rock animation adds no gravity field")
    var preview := Image.create(640, 320, false, Image.FORMAT_RGB8)
    for index in range(2):
        images[index].convert(Image.FORMAT_RGB8)
        preview.blit_rect(images[index], Rect2i(0, 0, 320, 320), Vector2i(index * 320, 0))
    preview.save_png("res://tests/hazard-animation.png")
    sector.free()
    print("Foreground hazard animation: 6 checks, %d failures" % failures)
    quit(0 if failures == 0 else 1)
