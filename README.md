# Space Taxi: Frontier - Playable v0.7

A Godot 4.3+ arcade flight game inspired by classic Space Taxi. Original sprite artwork is bundled with the project, each of the 20 environments has its own painted bitmap background, and sound is synthesized locally. No asset downloads or plugins are required to play.

## Play

Open `project.godot` in Godot and press **F5**. Choose **New Game** to start Level 1 with **three lives**, fresh credits, and no upgrades.

| Control | Action |
| --- | --- |
| A / D or Left / Right | Horizontal thrusters |
| W / Up / Space | Lift |
| S / Down | Brake and descend slowly |
| Escape | Pause / resume |
| Enter | Confirm the main menu or retry |
| M | Toggle sound |
| T | One emergency tow to PAD 02 per level, up to 100 credits |
| R | Retry the current level, costing one life |
| 1 / 2 / 3 / 4 at PAD 02 | Engine / stabilizers / tank / hull repair |

Controller flight: left stick steers, bottom face button lifts, right face button brakes.

## Passengers and star gates

1. Start on PAD 01 and fly to a marked pickup pad. Riders never spawn on the taxi's occupied or last-landed platform. They also avoid assigned dropoff pads, so each new trip needs a separate pickup.
2. Land and stay docked while the rider walks over to your taxi. Boarding takes at least one second and finishes when they reach the cabin. Taking off early makes them walk back to their waiting spot. Their destination is shown above the pad, in the cockpit, and on the map.
3. Deliver the rider to the marked destination. Faster trips earn a bonus. The next pickup is on another platform.
4. Complete three deliveries to open a **star gate at a random reachable location**. The last fare supplies 35 departure fuel for the flight to the exit. Gate locations vary in both horizontal position and height; follow the two-dimensional map and distance readout.
5. Take off and **fly through the star gate** to enter the next level. There is no N-key shortcut. The final gate completes the 20-level campaign.

Levels 1 and 2 have one waiting fare at a time. **Level 3 onward can have two simultaneous waiting fares**, and the player can choose either by landing at its pickup pad. The cockpit recommends a pickup while listing both riders and their remaining patience.

Waiting passengers become impatient and leave when their countdown reaches zero. Their markers turn red and they wave faster near the deadline. A missed fare increases the missed count; it does not count as a delivery or cost a life. Dispatch sends replacements after a short delay, so a missed rider cannot permanently block the level. Pausing freezes patience. Once boarded, passengers stay aboard while other waiting fares continue counting down.

## Flight, collisions, and lives

Normal flight uses consistent downward gravity on every level. **Planetary gravity fields, floating gravity objects, wind forces, and the gravity HUD have been removed.** Planets in the environmental backgrounds are decorative. Black holes exert a stronger inward pull within 340 units, with inward-streaming particles showing the danger. The taxi visibly accelerates toward them before contact. Entering a core triggers a comedic spin, stretch, and shrink capture sequence and costs exactly one life.

Hull damage is visible on the taxi: scratches and scorching at 75% hull, light gray smoke at 55%, cracked glass and heavier dark smoke at 30%, then glowing engine damage and sparks at 15%. Smoke rises from the damaged rear vent, leaves a trail during flight, and continues while docked. Repairing the hull reduces the damage effects; above 55% it stops smoking, and a full repair restores its clean appearance.

The taxi coasts when steering is released. Asteroids, moving gates, active beams, enemies, mines, meteors, and platform sides and undersides are solid. A collision stops the taxi at the surface and rebounds it; faster impacts cause more damage. Damage protection never disables solid collisions. The whole taxi must fit on the platform for a safe landing. Hold brake for a slow descent.

PAD 02 refuels on arrival and sells upgrades. Fuel use is balanced for separate pickup and delivery flights. Drones stop chasing into docking approaches, and docked taxis are protected.

A destroyed taxi erupts in a 1.4-second explosion: a white-hot flash, expanding shockwave, fire and smoke, 64 sparks, and eight spinning pieces of its actual sprite, with brief camera shake and a synthesized bass-and-crackle blast. Flight controls lock during destruction. The retry screen appears after the effect finishes, costing exactly one life. Pausing freezes the animation. Black-hole captures keep their separate comedic suction sequence and also cost one life. With lives remaining, retry the same level with a repaired and refueled taxi, keeping earned credits and upgrades. The level's fares restart. Losing the third taxi ends the run. Main Menu and Exit are available from pause and life-loss screens. Every New Game starts at Level 1 with three lives.

## Taller worlds and sprites

Every level is **2400 x 1440**, roughly two screens across and two screens high. The camera scrolls horizontally and vertically. Pads span over 800 vertical units, and enemies, mines, asteroids, beams, meteors, and black holes occupy different heights. The starting fuel tank holds 140 units; upgrades add 40 units each. Dispatch guidance accounts for vertical travel and avoids recommending fares whose pickup deadlines are already unrealistic.

The star gate is chosen randomly after the last delivery, at least 500 units from the taxi. Placement checks solid obstacles, platforms, the full black-hole drift area, and a connected navigation route. Its two-dimensional map marker helps locate an offscreen gate. Drones break off pursuit near the exit instead of camping inside it.

The taxi, purple alien scouts, red hunter drones, and three passenger designs use a transparent sprite atlas. Passengers animate between idle and waving poses, then adopt an impatient pose near their deadline. The taxi turns with steering, has a brake-jet sprite, and retains animated exhaust and black-hole deformation. The source atlas and built-in imagegen prompt are documented in `assets/sprites/README.md`.

## Bitmap environment artwork

Twenty original landscape PNGs in `assets/backgrounds/` match the campaign themes, from the observation hangar and ice aurora to volcanic crust and derelict stations. They cover the complete 2400 x 1440 world with an atmospheric veil that keeps the foreground readable. Backgrounds load when a sector is first visited and are cached for revisits.

`assets/sprites/frontier-props-v1.png` adds three platform styles, a fuel pump and hose, amber landing beacons, passenger terminals, steel trusses, a repair cabinet, and a fuel canister. Landing surfaces and mission markers remain aligned with the existing collision geometry. Original transparent PNGs are preserved; Godot selects trimmed atlas regions at runtime. Decorative service equipment does not block the docking lane.

The art was generated with the built-in imagegen tool. Exact prompts and the asset map are recorded in `assets/ARTWORK.md` and `assets/artwork-prompts.json`.

## Twenty environments

Each level has a distinct background composition, palette, and horizontal and vertical pad layout. Level 1 is an obstacle-free academy. At most one new enemy or obstacle family appears per level.

| Level | Environment | New challenge |
| --- | --- | --- |
| 1 | Orbital academy / observation hangar | Learn flight and single-fare pickups |
| 2 | Dust colony / desert mesas | New pad arrangement |
| 3 | Ice moon / aurora and crystal spires | Asteroids; two waiting fares |
| 4 | Copper canyon / stone bridges | Moving gates |
| 5 | First contact / fungal forest | Alien scouts |
| 6 | Neon crossing / rainy metropolis | Existing patrols and new routes |
| 7 | Twin horizons / binary suns | Multiple fares across elevated terminals |
| 8 | Alien outpost / honeycomb hive | Timed electric beams |
| 9 | Event horizon / deep-space void | Drifting black holes |
| 10 | Drifter's reach / orbital wheel station | Hunter drones |
| 11 | Binary dusk / sunset ridges | Tighter approaches and impatient riders |
| 12 | Scout belt / mining colony | Proximity mines |
| 13 | Singularity row / spatial rift | Paired black holes |
| 14 | Crimson transit / volcanic crust | Falling meteors |
| 15 | Floating garden / islands | Existing hazards around shifted terminals |
| 16 | Night patrol / moonlit ocean | Four scouts patrol tighter lanes |
| 17 | Violet current / nebula | Three black holes and two drones |
| 18 | Outer rim / derelict station | Narrow station docks |
| 19 | Last light / total eclipse | Twin meteor streams |
| 20 | Frontier's end / gateway colony | Final combination of familiar challenges |

## Validation

In PowerShell from the project directory:

```powershell
./tests/run.ps1
```

If needed, specify the executable:

```powershell
./tests/run.ps1 -GodotPath 'C:\path\to\godot.exe'
```

The runner checks import, mission integration, every level, solid collision physics, black-hole captures, lives and menus, actual application exit, passenger patience and concurrent fares, required star-gate transitions, sampled randomized gate reachability, two-screen camera movement, sprite transparency, and actual inward acceleration toward black holes. The automated pilot uses real controls and physics to complete all 60 deliveries and fly through all 20 randomized gates. The pilot uses actual service stops and repairs when needed. Later-level fixtures use normal tank upgrades and the same three-life retry system as the player. Tests use isolated saves and do not change the pilot's career. Runtime errors, warnings, failed checks, and incomplete runs fail validation. Logs are under `tests/`.

`tests/preview.gd` renders the campaign overview and previews of riders, star gates, menus, and black-hole animation with a graphical rendering driver. Example images are in `tests/`.

## Source map

- `scripts/main.gd`: cockpit, boarding, fares, star gates, upgrades, lives, menus, saves.
- `scripts/fares.gd`: simultaneous riders, dispatch rules, patience, replacements, pickup choices.
- `scripts/taxi.gd`: thrusters, inertia, landings, solid rebounds, damage, capture animation, fuel.
- `scripts/campaign.gd`: twenty named environments, difficulty settings, pad layouts.
- `scripts/sector.gd`: enemies, solid obstacles, moving black holes, localized suction.
- `scripts/scenery.gd`: twenty procedural background compositions.
- `scripts/audio.gd`: synthesized engine, music, and event cues.
- `scripts/radar.gd`: two-dimensional map, waiting fare markers, hazards, destination, star-gate marker.
- `scripts/world.gd`: shared level dimensions.
- `scripts/sprites.gd`: atlas regions and animation drawing.
- `assets/sprites/`: bundled sprite atlas and generation prompt.

This remains a playable prototype. Automated flights establish feasibility; human playtesting is needed for final feel, accessibility, and difficulty tuning. The soundtrack currently uses one shared synthesized music loop.
