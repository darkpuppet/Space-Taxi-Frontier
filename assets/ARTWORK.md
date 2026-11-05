# Environment bitmap artwork v1

Generated for Space Taxi: Frontier with the built-in `image_gen` tool. Original PNGs are copied intact into the project. Exact final generation prompts are in [artwork-prompts.json](artwork-prompts.json). No external asset packs or runtime downloads are required.

Each background covers the full 2400 x 1440 world; the original images are 1619 x 971 (972 pixels high for Level 11), and Godot fits them to the world rectangle. All scenic planets, structures, terrain, and asteroids in these images are distant decorative scenery. Actual solid hazards and landing surfaces are drawn separately in the foreground.

The environment renderer provides five scenic planes: stars, Earth/planets, window glass, solid window frame, and buildings. Level 1 uses extraction masks derived from its existing painting; other sectors retain their legacy painting until separated sprites are authored. See [background layers](../docs/background-layers.md) for masks, scroll rates and sprite slots.

| Level | Environment | Asset |
| --- | --- | --- |
| 1 | Orbital academy | [level-01-v1.png](backgrounds/level-01-v1.png) |
| 2 | Dust colony | [level-02-v1.png](backgrounds/level-02-v1.png) |
| 3 | Ice moon | [level-03-v1.png](backgrounds/level-03-v1.png) |
| 4 | Copper canyon | [level-04-v1.png](backgrounds/level-04-v1.png) |
| 5 | First contact | [level-05-v1.png](backgrounds/level-05-v1.png) |
| 6 | Neon crossing | [level-06-v1.png](backgrounds/level-06-v1.png) |
| 7 | Twin horizons | [level-07-v1.png](backgrounds/level-07-v1.png) |
| 8 | Alien outpost | [level-08-v1.png](backgrounds/level-08-v1.png) |
| 9 | Event horizon | [level-09-v1.png](backgrounds/level-09-v1.png) |
| 10 | Drifter's reach | [level-10-v1.png](backgrounds/level-10-v1.png) |
| 11 | Binary dusk | [level-11-v1.png](backgrounds/level-11-v1.png) |
| 12 | Scout belt | [level-12-v1.png](backgrounds/level-12-v1.png) |
| 13 | Singularity row | [level-13-v1.png](backgrounds/level-13-v1.png) |
| 14 | Crimson transit | [level-14-v1.png](backgrounds/level-14-v1.png) |
| 15 | Floating garden | [level-15-v1.png](backgrounds/level-15-v1.png) |
| 16 | Night patrol | [level-16-v1.png](backgrounds/level-16-v1.png) |
| 17 | Violet current | [level-17-v1.png](backgrounds/level-17-v1.png) |
| 18 | Outer rim | [level-18-v1.png](backgrounds/level-18-v1.png) |
| 19 | Last light | [level-19-v1.png](backgrounds/level-19-v1.png) |
| 20 | Frontier's end | [level-20-v1.png](backgrounds/level-20-v1.png) |

## Platform and service props

[frontier-props-v1.png](sprites/frontier-props-v1.png) is a 1280 x 1280 transparent atlas. Row 1 contains standard steel, orange industrial, and purple alien decks. Row 2 contains the fuel pump, beacon, and ticket terminal. Row 3 contains the support truss, repair cabinet, and fuel canister. Runtime atlas bounds trim padding without changing the source PNG. Row boundaries are 0%, 22%, 59%, and 100%; columns divide into equal thirds.
