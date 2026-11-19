# Editable level diagrams

Samples: **Level 5 — First Contact** and **Level 20 — Frontier's End**.
Open `level-05.svg` or `level-20.svg` in Inkscape or another SVG drawing program.
The PNG files are previews; edit the SVG originals.

## Editing

- Hide or lock the grid, movement guides and legend layers as needed.
- Move each labelled object group as a unit. Platforms include their deck and labels.
- Each object group has a stable ID (`P1`, `S1`, etc.) and a translation in world coordinates. The drawing has an additional page offset of (80, 160).
- Platform coordinates mark the center of the landing surface. Widths use game world units. Positive Y goes down.
- Labels and dashed guides are ordinary editable shapes: update them when moving objects, or leave a note for us to update them together.
- Save edited copies with a new filename, such as `level-05-proposed.svg`, so regeneration preserves your proposals.

The diagrams document gameplay objects, not decorative background scenery. Shapes represent hazard collision dimensions (diamonds are schematic 18-unit-radius bodies). Dashed boxes show center movement limits, excluding the body's radius. Drone boxes show nominal patrol targets, not pursuit limits. Meteor traces show only the first ten seconds and split at wrapping boundaries. Gravity has no hard range cutoff.

Positions show the configured state before the first physics tick. Scouts and wells begin moving with a phase offset; meteors shift to their wrapped flight lane on the first tick. Their initial markers therefore need not sit at the beginning of a displayed movement trace. The beam is drawn at its full extent regardless of its initial inactive state.

SVG edits are layout proposals. They do not automatically modify gameplay. We can apply revised platform positions to the level scenes and revised enemy/obstacle placement to the hazard configuration after review.

## Regeneration

From the project directory:

```powershell
& C:\software\godot\godot.exe --headless --path . --script tools/export-level-diagrams.gd
```

This overwrites the two sample SVGs. The exporter reads the actual level scenes, `configuration()` and `configure()` hazard arrays, rather than maintaining a second layout table. No gameplay files are changed.

To refresh the optional PNG previews, run `node tools/render-level-diagrams.cjs` in an environment with the `sharp` Node package available. A vector editor can also export PNGs directly. Godot's SVG rasterizer omits text, so it should not be used for these previews.
