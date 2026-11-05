# Background layers and parallax

Open `Environment.tscn` to tune the shared renderer. Each inherited level scene owns its own Environment instance, so settings and sprites can be changed per sector.

The requested back-to-front stack has five primary planes:

| Order | Plane | Contents | Camera response |
| --- | --- | --- | --- |
| 1 | StaticStarscape | Static starscape with nested animated stars and passing objects | Stars fixed on screen; activity moves at 90% horizontal / 94% vertical |
| 2 | EarthAndPlanets | Earth and moons, independently extracted from existing artwork | 97% horizontal / 98% vertical |
| 3 | WindowGlass | Translucent blue glass over both stars and planets | 99% horizontal / 99% vertical |
| 4 | WindowFrame | Solid outer frame, ceiling and edge columns | Matches the glass |
| 5 | Buildings | Station floor, towers, catwalks and control rooms | 100%, matching world movement |

The two window layers mean translucent glass followed by its solid frame. Animated stars, comets, passing ships, debris and the Ice Moon aurora remain nested in the bottommost plane, behind celestial objects. Disable `parallax_enabled` to restore world registration for all moving sprites while the static starscape remains screen-fixed.

Platforms, support trusses, hazards, taxi, passengers and gameplay effects remain above the scenery in the gameplay canvas. They receive no scenic parallax offsets, keeping collisions and landing positions aligned. The dashboard remains on its screen-space HUD.

## Level 1 artwork separation

The original `assets/backgrounds/level-01-v1.png` remains intact. Level 1 assigns artwork-aligned sprite masks under `assets/backgrounds/layers/level-01/`:

- `window-mask-v1.png` identifies open space behind the glass.
- `planets-mask-v1.png` selects Earth and the two moons.
- `frame-mask-v1.png` selects the outer observation-window structure.
- `buildings-mask-v1.png` selects the floor, buildings and control rooms.

These masks select pixels from the existing painting into separate Sprite2D planes. Overlapping solid masks are resolved so columns belong to the frame while closed control-room glazing belongs to buildings. The glass is a uniform blue tint at 6% opacity and includes the view over the planets; it contains no baked stars. A reconstructed celestial source fills the Earth behind structures so parallax does not expose building-shaped gaps.

The shared five-plane structure exists in every sector. Level 1 currently has the semantic extraction masks. Other sectors retain their existing painting through the buildings-plane fallback and static sky opening until their own masks or transparent plates are authored; the unassigned semantic planes stay hidden. No new generic replacement environments are introduced.

Overscan and a soft outer fade cover small offsets and scrolling beyond the world boundary. Pause freezes animated activity. Retries reset and reuse the current level's planes; changing sectors replaces the level scene and its environment.

## Authoring sprite plates

Each level's Environment exposes separate `sky_layer_texture`, `animated_layer_texture`, `planet_layer_texture`, `glass_layer_texture`, `frame_layer_texture` and `buildings_layer_texture` slots. Scene assignments take precedence over discovered PNGs.

Optional filenames under `assets/backgrounds/layers/level-01/` through `level-20/` are:

- `sky.png`: opaque static starscape, fitted to the logical viewport.
- `animated.png`: optional transparent starfield activity plate.
- `planets.png`: transparent celestial sprites.
- `glass.png`: translucent glass sprite.
- `frame.png`: transparent solid window-frame sprite.
- `buildings.png`: transparent nearest structures.

All moving plates share the 2400 x 1440 world coordinate system. Other source resolutions scale to that rectangle. Fill areas hidden behind nearer objects so movement will not reveal holes. Assigning a transparent plate bypasses the fallback extraction shader for that plane. The planet reconstruction slot supplies an opaque color source that still uses the planet mask.

Run `tests/environment-layers.gd` for ordering, parallax, lifecycle and gameplay isolation checks. `tests/window-glass.gd` additionally renders isolated planes to verify that Earth, glass, frame and buildings occupy the intended sprites. Graphical runs save previews in `.development/`.
