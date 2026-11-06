extends RefCounted
## Crush the actual cab painting through localized, cumulative body failures.
const COLUMNS: int = 12
const ROWS: int = 6
## Seconds from capture entry. The offline WAV generator uses this same score.
const BUCKLE_TIMES: Array[float] = [0.12, 0.62, 0.98, 1.24, 1.43, 1.57]
const BUCKLE_DURATION: float = 0.085
const SWALLOW_TIME: float = 1.70
const DURATION: float = 2.10
const POP_DURATION: float = 0.18
const FAST_TIME: float = 0.65
const FASTEST_TIME: float = 1.35

## Three increasingly frantic speeds: a reluctant drift, a spin, then a gulp.
static func travel_at(seconds: float) -> float:
    var t: float = clampf(seconds, 0.0, DURATION)
    if t < FAST_TIME:
        return t * 0.16
    if t < FASTEST_TIME:
        return FAST_TIME * 0.16 + (t - FAST_TIME) * 0.48
    var covered: float = FAST_TIME * 0.16 + (FASTEST_TIME - FAST_TIME) * 0.48
    return covered + (t - FASTEST_TIME) * (1.0 - covered) / (DURATION - FASTEST_TIME)

static func progress_at(seconds: float) -> float:
    var crush: float = 0.0
    for onset in BUCKLE_TIMES:
        crush += smoothstep(onset, onset + BUCKLE_DURATION, seconds) / BUCKLE_TIMES.size()
    return clampf(crush, 0.0, 1.0)

## A tiny white-gold glint and violet halo where the wreck vanishes.
static func paint_pop(canvas: CanvasItem, age: float) -> void:
    if age < 0.0 or age >= POP_DURATION:
        return
    var progress: float = age / POP_DURATION
    var opacity: float = pow(1.0 - progress, 2.0)
    var radius: float = lerpf(8.0, 19.0, progress)
    for layer in range(5, 0, -1):
        canvas.draw_circle(Vector2.ZERO, radius * float(layer) / 5.0, Color(0.8, 0.55, 1.0, opacity * 0.08))
    var size: float = lerpf(12.0, 17.0, progress)
    var glint := PackedVector2Array([
        Vector2(-size, 0), Vector2(-2, -2), Vector2(0, -size * 0.8), Vector2(2, -2),
        Vector2(size, 0), Vector2(2, 2), Vector2(0, size * 0.8), Vector2(-2, 2)])
    canvas.draw_colored_polygon(glint, Color(1.0, 0.91, 0.68, opacity))
    canvas.draw_circle(Vector2.ZERO, lerpf(4.0, 1.0, progress), Color(1.0, 1.0, 1.0, opacity))

## Each of the six crunches collapses a different part of the body.
static func stage(crush: float, index: int) -> float:
    return smoothstep(float(index), float(index + 1), clampf(crush, 0.0, 1.0) * 6.0)

static func point(uv: Vector2, crush: float) -> Vector2:
    var p := Vector2(uv.x * 74.0 - 37.0, uv.y * 39.0 - 18.0)
    var roof: float = stage(crush, 0)
    var nose: float = stage(crush, 1)
    var rear: float = stage(crush, 2)
    var floor: float = stage(crush, 3)
    var cabin: float = stage(crush, 4)
    var compact: float = stage(crush, 5)
    var roof_area: float = exp(-pow((uv.x - 0.50) / 0.28, 2.0))
    var front_area: float = smoothstep(0.57, 1.0, uv.x)
    var rear_area: float = 1.0 - smoothstep(0.0, 0.39, uv.x)
    # 1: cave the roof and windshield into the passenger compartment.
    p.y += roof * roof_area * pow(1.0 - uv.y, 2.0) * 12.0
    # 2: fold the hood back toward the cabin, lifting the front bumper.
    p.x -= nose * front_area * 19.0
    p.y -= nose * front_area * (2.0 + uv.y * 7.0)
    # 3: crush the engine housing inward from the rear.
    p.x += rear * rear_area * 16.0
    p.y += rear * rear_area * (3.0 - uv.y * 9.0)
    # 4: buckle the undercarriage upward while the damaged roof stays low.
    p.y -= floor * smoothstep(0.40, 1.0, uv.y) * 7.0
    # 5: collapse the cabin sideways with an off-center dent, not even pleats.
    p.x = lerpf(p.x, p.x * 0.80 + (uv.y - 0.5) * 5.0, cabin)
    p.y += cabin * roof_area * (1.0 - uv.y) * 3.0
    # 6: squeeze the bent panels into a compact, lopsided wreck.
    p.x = lerpf(p.x, p.x * 0.74 + (uv.y - 0.5) * 2.0, compact)
    p.y = lerpf(p.y, p.y * 0.92 + (uv.x - 0.5) * 4.0, compact)
    return p

static func paint(canvas: CanvasItem, texture: Texture2D, crush: float) -> void:
    for column in range(COLUMNS):
        for row in range(ROWS):
            var uv := PackedVector2Array([
                Vector2(float(column) / COLUMNS, float(row) / ROWS),
                Vector2(float(column + 1) / COLUMNS, float(row) / ROWS),
                Vector2(float(column + 1) / COLUMNS, float(row + 1) / ROWS),
                Vector2(float(column) / COLUMNS, float(row + 1) / ROWS)])
            var vertices := PackedVector2Array()
            for coordinate in uv:
                vertices.append(point(coordinate, crush))
            var x: float = (float(column) + 0.5) / COLUMNS
            var shade: float = 1.0 - crush * 0.10
            shade -= stage(crush, 1) * smoothstep(0.57, 1.0, x) * 0.13
            shade -= stage(crush, 2) * (1.0 - smoothstep(0.0, 0.39, x)) * 0.16
            canvas.draw_polygon(vertices, PackedColorArray([Color(shade, shade, shade)]), uv, texture)
    # A few short creases at actual body failures, rather than striped mesh edges.
    var creases: Array[PackedVector2Array] = [
        PackedVector2Array([Vector2(0.34, 0.13), Vector2(0.48, 0.27), Vector2(0.63, 0.18)]),
        PackedVector2Array([Vector2(0.73, 0.36), Vector2(0.66, 0.58), Vector2(0.79, 0.73)]),
        PackedVector2Array([Vector2(0.21, 0.28), Vector2(0.28, 0.51), Vector2(0.17, 0.70)]),
        PackedVector2Array([Vector2(0.34, 0.84), Vector2(0.48, 0.76), Vector2(0.64, 0.85)]),
        PackedVector2Array([Vector2(0.43, 0.43), Vector2(0.53, 0.60), Vector2(0.65, 0.53)])]
    for index in range(creases.size()):
        var amount: float = stage(crush, index)
        if amount <= 0.01:
            continue
        var crease := PackedVector2Array()
        for coordinate in creases[index]:
            crease.append(point(coordinate, crush))
        canvas.draw_polyline(crease, Color(0.16, 0.11, 0.06, amount * 0.65), 0.75, true)
