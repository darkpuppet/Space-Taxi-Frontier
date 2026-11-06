extends RefCounted
## Buckle the actual cab painting into an accordion of dented metal panels.
const COLUMNS: int = 12
const ROWS: int = 4
## Seconds from capture entry. The offline WAV generator uses this same score.
const BUCKLE_TIMES: Array[float] = [0.12, 0.46, 0.80, 1.14, 1.48, 1.82]
const BUCKLE_DURATION: float = 0.085
const SWALLOW_TIME: float = 2.10
const DURATION: float = 2.65

static func progress_at(seconds: float) -> float:
    var crush: float = 0.0
    for onset in BUCKLE_TIMES:
        crush += smoothstep(onset, onset + BUCKLE_DURATION, seconds) / BUCKLE_TIMES.size()
    return clampf(crush, 0.0, 1.0)

static func point(uv: Vector2, crush: float) -> Vector2:
    var p := Vector2(uv.x * 74.0 - 37.0, uv.y * 39.0 - 18.0)
    var fold: float = cos(uv.x * TAU * 6.0)
    var roof: float = clampf(crush * 3.0, 0.0, 1.0)
    var ends: float = smoothstep(0.16, 0.67, crush)
    var concertina: float = smoothstep(0.33, 1.0, crush)
    p.x *= lerpf(1.0, 0.36, ends * 0.35 + concertina * 0.65)
    p.x += sin(uv.y * PI) * sin(uv.x * TAU * 3.0) * crush * 0.8
    p.y *= lerpf(1.0, 0.62, concertina)
    p.y += fold * concertina * (3.0 + absf(uv.y - 0.5) * 7.0)
    # The roof caves in and the bumper ends fold toward the cabin.
    p.y += sin(uv.x * PI) * (1.0 - uv.y) * roof * 9.0
    p.y -= pow(absf(uv.x * 2.0 - 1.0), 3.0) * ends * 5.0
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
            var shade: float = lerpf(1.0, 0.52 if column % 2 else 1.08, crush)
            canvas.draw_polygon(vertices, PackedColorArray([Color(shade, shade, shade)]), uv, texture)
    if crush > 0.05:
        for column in range(1, COLUMNS):
            var x: float = float(column) / COLUMNS
            var crease := PackedVector2Array()
            for row in range(ROWS + 1):
                crease.append(point(Vector2(x, float(row) / ROWS), crush))
            canvas.draw_polyline(crease, Color(0.13, 0.10, 0.06, crush * 0.7), 0.65, true)
