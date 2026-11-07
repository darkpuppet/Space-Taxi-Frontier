# Repainted background layers

All 20 level scenes use independently repainted RGBA scenery. Original `level-NN-v1.png` paintings remain as style references and editor overview art. Runtime scenery does not cut those paintings apart, sample semantic masks, key out colors, or repair extraction edges.

Each scene renders six populated scenery planes with distinct camera rates. The sky uses 0.04 / 0.025 and moves slowly behind the other five planes. Each scene assigns `authored_depth_textures` in back-to-front order:

| Plate | Contents | Horizontal / vertical camera scale |
| --- | --- | --- |
| `distant-v2.png` | Small distant celestial objects | 0.90 / 0.94 |
| `middle-v2.png` | Main planets, moons and suns | 0.94 / 0.96 |
| `far-v2.png` | Far landscape and buildings | 0.97 / 0.98 |
| `near-v2.png` | Near landscape and buildings | 0.985 / 0.99 |
| `front-v2.png` | Closest rocks, foliage and structures | 1.0 / 1.0 |

These files live under `assets/backgrounds/layers/level-NN/`. Every depth slot contains visible artwork. Sectors without celestial bodies use distant city skylines or derelict structures instead. The starscape uses the previously reconstructed `sky-v1.png` plates for levels 02-20 and the new `sky-v2.png` for level 01. Every plate shares the full world coordinate frame; complete silhouettes and surfaces behind overlapping objects are painted into their own layers. World overscan covers solid-plane boundaries. Screen-space sky overscan covers its slow travel without exposing gaps.

Level 01 uses the five slots for distant moon, Earth, far orbital outposts, observation frame and station deck. Its six-percent clear glass tint is attached behind the observation frame and travels with it, preserving all six independent scenery depths.

The built-in imagegen tool repainted the plates from the original paintings as visual references. `repainted-plate-prompts.json` and `repainted-hires-prompts.json` and `six-layer-completion-prompts.json` record the generation prompts. Initial distant plates were exported from transparent atlases using `tools/split-background-atlases.ps1`; larger scenery is painted as individual full-resolution images to retain detail at gameplay zoom. Alpha is supplied by generation and preserved on import. No color-key cleanup is used. Old depth-mask assets and extraction shaders are retained for historical compatibility; the campaign scenes no longer assign them.

Twinkles remain registered with the slowly parallaxing sky. Passing ships, comets and debris retain their own movement. Ice Moon animates only its repainted sky behind solid scenery and freezes on pause. Retries reuse scenic nodes. Platforms, collisions, taxi, passengers and the dashboard remain independent from scenic camera offsets.

Level 06 uses a rain-free `assets/backgrounds/layers/level-06/sky-v1.png`. Built-in imagegen edit prompt: "Remove ALL rain streaks; preserve the storm clouds, composition, blue/violet colors, lighting, aspect ratio and painterly texture; no new objects, stars or text." `rain_layer.gd` draws seeded falling streaks at two depths: middle rain behind near scenery and larger, faster foreground rain over the front plate. Both follow their scenery camera rates, freeze with the sector on pause, and reuse their nodes on retry. `tests/rain.gd` checks ordering, animation, pause, retries and isolation from other levels.

Run `tests/run.ps1` for complete validation. `environment-layers.gd` checks camera rates, ordering, zoom, pause and transitions. `depth-extraction.gd` now validates all 20 repainted sets: visible content in every plane, real alpha, absence of broad white backdrops, direct shader-free rendering, isolated foreground transparency, and coverage at multiple camera positions. It saves full-world and close-travel previews plus a contact sheet under `.development/depth-previews/`. `window-glass.gd` checks independent Earth, glass, frame and deck treatment. `aurora.gd` checks the localized animation lifecycle.
