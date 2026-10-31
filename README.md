# Space Taxi: Frontier — Playable v0.2

A 2D sci-fi arcade taxi game built for Godot 4.x. No third-party assets or plugins.

## Getting started
1. Extract the ZIP.
2. In Godot 4.3+, import `project.godot`.
3. Press F5 to play.

## Flight controls
- A / D or Left / Right: responsive horizontal steering
- W / Up / Space: vertical thrusters
- S / Down: powerful air brakes and landing stabilizer
- Controller: left stick, bottom face button (lift), right face button (brake)
- R: restart the current shift
- N: next shift after 3 completed fares

## Game loop
1. Begin on PAD 01. Press lift to take off, then return and land to pick up the first passenger.
2. Deliver to the highlighted destination pad; the game automatically assigns the next fare.
3. Finish three fares to complete the shift and advance to the next environment.
4. PAD 02 refuels your taxi (+40 units on landing) and hosts the upgrade shop.
5. While landed on PAD 02, press 1 (engine, 400 credits), 2 (stabilizers, 350), 3 (fuel tank, 300), or 4 (repair, 75).
6. Credits, upgrades, deliveries, and unlocked shift number are saved locally.

## Landing model
The taxi now automatically settles onto a platform when it approaches from above inside the marked landing corridor at a reasonable speed. Harder impacts cause a bounce and partial damage rather than an instant death. Braking slows both axes and makes landings substantially easier.

## Project structure
- `Main.tscn`: game scene
- `Taxi.tscn`: vehicle scene
- `scripts/main.gd`: missions, environment, camera, HUD, upgrades, saves
- `scripts/taxi.gd`: flight controls, landing, damage, fuel

## Limitations
This is a more complete playable *vertical slice*, not a content-complete commercial release. Graphics remain procedural and audio is not implemented. Four environment palettes rotate through an indefinitely expanding shift sequence. Physics and game scripts have not been validated by a Godot executable in this environment, so report any import/runtime errors and they can be corrected.
