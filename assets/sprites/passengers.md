# Later passenger types

The original three passengers remain available throughout the campaign. New types join at these levels:

| First level | Passenger | Appearance |
| --- | --- | --- |
| 6 | Crystal traveler | Cyan and amethyst crystal body, purple traveling coat |
| 11 | Insectoid traveler | Amber chitin, antennae, olive vest |
| 16 | Robot courier | White and coral body, cyan screen face, parcel backpack |

The first fare on each debut level introduces that type. Later fares cycle through all unlocked types, including replacements. Selection is stored with the fare so waiting, boarding, voice, and accident behavior agree. Retries preserve the introduction. Prices, patience, and boarding rules are unchanged. Crystal and insectoid travelers use the six alien customer voices. Robot couriers use a dedicated metallic synthetic voice. All three use the alien accident sound.

`scripts/passenger_types.gd` owns the unlock and species metadata. Level indices in code are zero-based; unlocks above are player-facing.

`frontier-passengers-v2.png` is an original transparent atlas generated with the built-in imagegen tool, using `frontier-atlas-v1.png` as a style reference. Three equal rows contain crystal, insectoid, and robot characters. Eight equal columns contain idle, small wave, overhead wave, impatient, and four walking poses. The original image is preserved; `scripts/sprites.gd` trims each cell at runtime and anchors it by the feet. Impatient boots use the existing foot-tap animation.

Preview all six characters with `tests/impatient-sprites.gd`; unlock and boarding coverage is in `tests/passengers.gd`, and species voice coverage is in `tests/dispatch-radio.gd`.
