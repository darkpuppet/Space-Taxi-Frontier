# Editing campaign levels

Each sector has its own inherited Godot scene, `levels/level_01.tscn` through `levels/level_20.tscn`. They inherit `levels/level_base.tscn` so shared behavior stays reusable. Open a level scene directly to edit it; F6 starts that sector in the real game shell with career saving disabled.

The composition follows Godot's [scene organization guidance](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html): the main controller owns session state and connects dependencies, while level-local artwork, environment and landing positions belong to the level scene.

## Scene contents

- The root runs `scripts/level.gd`, extending the shared hazard simulation in `sector.gd`. Its sector index selects campaign difficulty and economy defaults. `configuration_overrides` allows local changes without copying shared code.
- `ArtworkPreview` shows the existing sector PNG in the 2D editor. It is hidden in gameplay, where five scenic layers render the artwork.
- `Environment` instances `Environment.tscn`. Editable children let each level override parallax rates and assign starscape, planets, glass, frame and buildings sprites, with animated starfield activity nested in the lowest layer.
- `Aurora` supplies the Ice Moon animation. At runtime the environment places it in its animated plane.
- `Pads/Pad01` through `Pad05` are editable landing markers. Their positions, deck widths and service lists are the source of truth for gameplay.

Move the pad markers in the 2D editor to change docking positions. The editor draws each deck width and ID over the original background for alignment. Keep IDs 1–5 unique; pad 2 supplies the fuel/workshop services. Validation warnings on the level root flag missing artwork or invalid IDs.

Assign the existing source background on the root's `background_texture` property. New separated scenery sprites can be assigned on that level's Environment instance; they should use the shared world coordinate system described in [background layers](background-layers.md).

## Runtime ownership

`Main.tscn` remains the application entry point. It loads the selected level as a PackedScene and owns the taxi, HUD, audio, passenger dispatch and persistent progress. The current level root owns its hazards, environment and pad markers. Main passes the scene's layout to flight and hazards so visual landing locations and collisions stay consistent.

Retries reset and reuse the current level scene. Changing sectors replaces the previous level root and its children. Fuel, hull, upgrades, balance and distance still follow the existing campaign rules. Background renderer instances now belong to their individual level scenes.

`campaign.gd` retains the shared progression formulas and campaign order. Its `pads_for()` compatibility helper reads markers from the corresponding scene; there is no second hard-coded layout table.

## Campaign scenes

| Scene | Sector |
| --- | --- |
| `level_01.tscn` | Orbital Academy |
| `level_02.tscn` | Dust Colony |
| `level_03.tscn` | Ice Moon |
| `level_04.tscn` | Copper Ridge |
| `level_05.tscn` | First Contact |
| `level_06.tscn` | Neon Crossing |
| `level_07.tscn` | Twin Horizons |
| `level_08.tscn` | Alien Outpost |
| `level_09.tscn` | Event Horizon |
| `level_10.tscn` | Drifter's Reach |
| `level_11.tscn` | Binary Dusk |
| `level_12.tscn` | Scout Belt |
| `level_13.tscn` | Singularity Row |
| `level_14.tscn` | Crimson Transit |
| `level_15.tscn` | Floating Garden |
| `level_16.tscn` | Night Patrol |
| `level_17.tscn` | Violet Current |
| `level_18.tscn` | Outer Rim |
| `level_19.tscn` | Last Light |
| `level_20.tscn` | Frontier's End |

Run `tests/level-scenes.gd` for all-scene loading, editor-marker integration, transitions, retry reuse and direct scene preview checks.
