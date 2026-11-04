extends RefCounted
const WIDTH: float = 2400.0
const HEIGHT: float = 1440.0
const FLOOR: float = 1400.0
## Design scale: the 74-world-pixel taxi is a 4.5-meter vehicle.
const TAXI_LENGTH_PIXELS: float = 74.0
const TAXI_LENGTH_METERS: float = 4.5
const METERS_PER_WORLD_PIXEL: float = TAXI_LENGTH_METERS / TAXI_LENGTH_PIXELS
const WORLD_PIXELS_PER_KILOMETER: float = 1000.0 / METERS_PER_WORLD_PIXEL

static func meters(world_pixels: float) -> float:
    return world_pixels * METERS_PER_WORLD_PIXEL
const NAV_ROWS: int = 20
