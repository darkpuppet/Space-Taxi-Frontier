extends RefCounted
## Atlas regions are trimmed at runtime; the original generated PNG is preserved.
const ATLAS: Texture2D = preload("res://assets/sprites/frontier-atlas-v1.png")
static var frames: Array[Texture2D] = []

const LATER_RIDERS: Texture2D = preload("res://assets/sprites/frontier-passengers-v2.png")
static var later_frames: Array[Texture2D] = []

static func prepare_later_riders() -> void:
	if later_frames.is_empty():
		later_frames = preload("res://scripts/atlas_regions.gd").frames_for(LATER_RIDERS)

static func _new_rider(canvas: CanvasItem, foot: Vector2, variant: int, pose: int) -> void:
	prepare_later_riders()
	var first: int = clampi(variant - 3, 0, 2) * 8
	var texture: Texture2D = later_frames[first + pose]
	var size: Vector2 = texture.get_size() * (42.0 / later_frames[first].get_height())
	canvas.draw_texture_rect(texture, Rect2(foot - Vector2(size.x * 0.5, size.y), size), false)

static func _new_impatient_rider(canvas: CanvasItem, foot: Vector2, variant: int, clock: float) -> void:
	prepare_later_riders()
	var first: int = clampi(variant - 3, 0, 2) * 8
	var texture: Texture2D = later_frames[first + 3]
	var pixels: Vector2 = texture.get_size()
	var scale: float = 42.0 / later_frames[first].get_height()
	var size: Vector2 = pixels * scale
	var origin: Vector2 = foot - Vector2(size.x * 0.5, size.y)
	var boot_x: float = floorf(pixels.x * 0.55)
	var boot_y: float = floorf(pixels.y * 0.84)
	canvas.draw_texture_rect_region(texture, Rect2(origin, Vector2(size.x, boot_y * scale)), Rect2(0, 0, pixels.x, boot_y))
	canvas.draw_texture_rect_region(texture, Rect2(origin + Vector2(0, boot_y * scale), Vector2(boot_x, pixels.y - boot_y) * scale), Rect2(0, boot_y, boot_x, pixels.y - boot_y))
	canvas.draw_set_transform(origin + Vector2(boot_x, boot_y) * scale, foot_tap_angle(clock))
	canvas.draw_texture_rect_region(texture, Rect2(Vector2.ZERO, Vector2(pixels.x - boot_x, pixels.y - boot_y) * scale), Rect2(boot_x, boot_y, pixels.x - boot_x, pixels.y - boot_y))
	canvas.draw_set_transform(Vector2.ZERO)

static func _ensure() -> void:
	if frames.is_empty():
		frames = preload("res://scripts/atlas_regions.gd").frames_for(ATLAS)

static func ship(canvas: CanvasItem, type: int, rect: Rect2) -> void:
	_ensure()
	canvas.draw_texture_rect(frames[clampi(type, 0, 3)], rect, false)

static func rider(canvas: CanvasItem, foot: Vector2, variant: int, pose: int) -> void:
	if variant >= 3:
		_new_rider(canvas, foot, variant, clampi(pose, 0, 3))
		return
	_ensure()
	var first: int = 4 + posmod(variant, 3) * 4
	var texture: Texture2D = frames[first + clampi(pose, 0, 3)]
	var scale: float = 42.0 / frames[first].get_height()
	var size: Vector2 = texture.get_size() * scale
	canvas.draw_texture_rect(texture, Rect2(foot - Vector2(size.x * 0.5, size.y), size), false)

const WALK_ATLAS: Texture2D = preload("res://assets/sprites/frontier-walk-v1.png")
static var walk_frames: Array[Texture2D] = []

static func prepare_walk() -> void:
	if walk_frames.is_empty():
		walk_frames = preload("res://scripts/atlas_regions.gd").frames_for(WALK_ATLAS)

static func walking_rider(canvas: CanvasItem, foot: Vector2, variant: int, clock: float, direction: float) -> void:
	if variant >= 3:
		canvas.draw_set_transform(foot, 0, Vector2(-1 if direction < 0 else 1, 1))
		_new_rider(canvas, Vector2.ZERO, variant, 4 + posmod(int(clock * 8.0), 4))
		canvas.draw_set_transform(Vector2.ZERO)
		return
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
	if variant >= 3:
		_new_impatient_rider(canvas, foot, variant, clock)
		return
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
