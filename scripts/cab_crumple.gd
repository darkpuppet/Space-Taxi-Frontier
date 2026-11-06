extends RefCounted
## Buckle the actual cab painting into an accordion of dented metal panels.
const COLUMNS: int = 12
const ROWS: int = 4

static func point(uv: Vector2, crush: float) -> Vector2:
    var p := Vector2(uv.x * 74.0 - 37.0, uv.y * 39.0 - 18.0)
    var fold: float = cos(uv.x * TAU * 6.0)
    p.x *= lerpf(1.0, 0.36, crush)
    p.x += sin(uv.y * PI) * sin(uv.x * TAU * 3.0) * crush * 0.8
    p.y *= lerpf(1.0, 0.62, crush)
    p.y += fold * crush * (3.0 + absf(uv.y - 0.5) * 7.0)
    # The roof caves in and the bumper ends fold toward the cabin.
    p.y += sin(uv.x * PI) * (1.0 - uv.y) * crush * 5.0
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
