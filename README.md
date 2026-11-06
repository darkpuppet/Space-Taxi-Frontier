# Space Taxi: Frontier - Playable v0.7

A Godot 4.7 arcade flight game inspired by classic Space Taxi. Original sprite artwork is bundled with the project, each of the 20 environments has its own painted bitmap background, and sound combines local synthesis with bundled CB radio dispatch clips. No asset downloads or plugins are required to play.

## Play

Use **Godot 4.7.2 stable**, installed at `C:\software\godot\godot.exe`. Open `project.godot` with that executable and press **F5**. Choose **New Game** to start Level 1 with **three lives**, fresh credits, and no upgrades.

| Control | Action |
| --- | --- |
| A / D or Left / Right | Horizontal thrusters |
| W / Up / Space | Lift |
| S / Down | Brake and descend slowly |
| Escape | Pause / resume |
| Enter | Confirm the main menu or retry |
| M | Toggle sound |
| T | Call Bubba's tow truck to PAD 02 once per level, 300 credits |
| R | Ask to retry the current level; confirming costs one life |
| 1 / 2 / 3 / 4 at PAD 02 | Engine / stabilizers / tank / hull repair |

Controller flight: left stick steers, bottom face button lifts, right face button brakes.

The resizable window scales the entire game and HUD from a 1280 x 720 design viewport. The 16:9 aspect ratio stays fixed; wider or taller window shapes add borders instead of stretching or cropping the picture.

Accidentally landing on a passenger plays a brief cartoon scream alongside the squish, with distinct human and alien voices.

Pickup calls announce each new waiting customer's pad over a crackly CB radio voice. Each level randomly selects a male, female, or robot dispatcher and keeps that voice through retries. Each voice has six pickup phrases, shuffled without immediate repeats; every call names the actual pickup pad. Pickup calls last about three to five seconds. When the stargate appears, the same dispatcher announces that it is open and tells you to head for it. Calls play one at a time, pause with the game, and respect **M** to mute. Music dips during speech. Voice clips work offline on every platform without installed speech software.

## Passengers and star gates

1. Start on PAD 01 and fly to a marked pickup pad. Passenger pickups and dropoffs use terminal platforms only. Fuel and repair platforms are reserved for service and never receive fares. Riders never spawn on the taxi's occupied or last-landed platform. They also avoid assigned dropoff pads, so each new trip needs a separate pickup.
2. Land and stay docked while the rider walks over to your taxi. Once aboard, the passenger says their actual destination, such as "Platform three, please." Boarding takes at least one second and finishes when they reach the cabin. Taking off early makes them walk back to their waiting spot. Their destination is shown above the pad, in the cockpit, and on the map.
3. Deliver the rider to the marked destination. Faster trips earn a bonus. A transparent glass lift rises from inside the destination pad as the occupied taxi approaches, on the side opposite the cab. After leaving the taxi, the passenger walks across the platform, enters the lift, and remains visible through its doors as it descends into the pad. Elevators appear only for expected or ongoing drop-offs and disappear when retracted. You can depart immediately; the walk and lift freeze during pause and clear when the level restarts. The next pickup is on another platform.
4. Complete three deliveries to open a **star gate at a random reachable location**. The last fare supplies 35 departure fuel for the flight to the exit. Gate locations vary in both horizontal position and height; follow the two-dimensional map and distance readout.
5. Take off and **fly through the star gate** to enter the next level. There is no N-key shortcut. The final gate completes the 20-level campaign.

Levels 1 and 2 have one waiting fare at a time. **Level 3 onward can have two simultaneous waiting fares**, and the player can choose either by landing at its pickup pad. The cockpit recommends a pickup while listing both riders and their remaining patience.

Land beside waiting passengers rather than on top of them. A descending taxi that strikes a fare kills that passenger and incurs a 250-credit fine, including debt when necessary. It does not count as a delivery or cost a taxi life. A short squish sound and a small red human or green alien splatter mark the accident. A little gravestone rises immediately afterward, stays for at least three seconds, and clears when a replacement fare spawns. Pausing freezes the effect; restarting clears memorials. Dispatch replaces the lost fare after a delay.

Waiting passengers become impatient and leave when their countdown reaches zero. Their markers turn red and they wave faster near the deadline. A missed fare increases the missed count; it does not count as a delivery or cost a life. Dispatch sends replacements after a short delay, so a missed rider cannot permanently block the level. Pausing freezes patience. Once boarded, passengers stay aboard while other waiting fares continue counting down.

## Flight, collisions, and lives

Normal flight uses consistent downward gravity on every level. **Planetary gravity fields, floating gravity objects, wind forces, and the gravity HUD have been removed.** Planets in the environmental backgrounds are decorative. Black holes pull the taxi inward from anywhere on the playfield, with a softened inverse-square falloff: the pull weakens smoothly with distance and grows stronger near the core. Docked taxis are protected; suction resumes on takeoff or sliding off a platform. A broader falloff makes the approach pull more noticeable. Multiple singularities combine their pulls; total acceleration is capped so stock thrusters can still overcome it. Inward-streaming particles around each core show the danger. The taxi visibly accelerates toward them before contact. Their sprite-based accretion disks counter-rotate and pulse, with contracting light ripples, 64 inward-spiraling dust motes, and hot sparks racing around the core. The glow intensifies as the taxi approaches; animation follows the paused game clock. Entering a core crushes the painted taxi through six distinct held stages: the roof caves in, the nose folds back, the rear engine housing collapses inward, the undercarriage buckles upward, the cabin slumps sideways, and the bent body compacts into an irregular wreck. Local dents and short creases follow the damaged parts of the car. The 2.1-second sequence accelerates through slow, fast, and fastest crushing, with progressively quicker buckles and a frantic final gulp. The taxi locks upright to the singularity center as soon as capture starts and stays centered while crushing, following the same singularity as it drifts. The wreck stays full-sized until the final swallow, then shrinks all the way to zero while remaining opaque. A larger white-gold flash blooms at that exact instant, with an expanding violet ring and rotating rays fading over 0.32 seconds before the retry screen appears. Each buckle matches a metallic crunch in the bundled 48 kHz stereo PCM WAV, `assets/audio/taxi-can-crumple.wav`. The sound uses one continuous recording of an empty aluminum soda can being crushed (FOSSarts, CC0), preserving the natural pitch, speed, crinkles, and creaks between collapses. Capture lowers the music and plays no synthesized suction jingle. The recording is trimmed offline with `tools/audio/generate-crumple.gd` using the animation's shared timing constants in `scripts/cab_crumple.gd`. Source and license details are in `tools/audio/sources/README.md`. The motion and crushing sound pause together, cancel on a restart or return to the menu, and cost exactly one life. Muting keeps playback advancing so unmuting preserves synchronization.

Hull damage is visible on the taxi: scratches and scorching at 75% hull, light gray smoke at 55%, cracked glass and heavier dark smoke at 30%, then glowing engine damage and sparks at 15%. Smoke rises from the damaged rear vent, leaves a trail during flight, and continues while docked. Repairing the hull reduces the damage effects; above 55% it stops smoking, and a full repair restores its clean appearance.

The taxi coasts when steering is released. Asteroids, moving gates, active beams, enemies, mines, meteors, and platform sides and undersides are solid. A collision stops the taxi at the surface and rebounds it; faster impacts cause more damage. Damage protection never disables solid collisions. More than half of the taxi must overlap the platform to stay supported. A/D can move the taxi along a dock; moving too far over an edge makes it slide off and fall. Platforms have five different widths per level, narrowing gradually from 200ÃƒÂ¯Ã‚Â¿Ã‚Â½260 units in Level 1 to 105ÃƒÂ¯Ã‚Â¿Ã‚Â½165 in Level 20. Hold brake for a slow descent.

PAD 02 pumps paid fuel continuously while parked, stopping when the tank is full, credits run out, or you take off. The gas-station sign shows the current price: **2-10 credits per unit**, changing every 30 seconds of unpaused play. Pump speed is fixed at **15 fuel units per second**, regardless of tank upgrades: about **9.3 seconds** for the stock 140-unit tank and **20 seconds** for the fully upgraded 300-unit tank. The pump supplies life support during filling so idle consumption does not extend the fill time. Even your last credit buys a fraction of a unit. Landing no longer grants free fuel. The pad also sells upgrades. Drones stop chasing into docking approaches, and docked taxis are protected.

An empty tank automatically calls **Bubba's rusty space tow truck**, even if your manual T-key/controller-Y call-out was already used. His patched rust-bucket flies over, lowers its hook to the taxi roof, reels in the winch to lift the taxi, and carries it through a protective recovery field to PAD 02. The truck hovers above the platform while paying out the cable to gently set the taxi down, then retracts its hook and flies away. Its eight-frame sprite sheet has separate four-frame hover and powered-flight animations: bright twin blue lift jets and a rear maneuvering thruster during travel, softer sputtering jets during hookup and setdown, a rotating amber beacon, blinking red and teal running lights, flickering headlights, and smoky exhaust. The rusty cab shudders and bobs with its engine. Its clunker engine combines deep uneven combustion thuds, delayed piston knocks, loose-metal rattles, and breathy exhaust with occasional misfire coughs. The tired engine wavers in pitch, revs louder under load during flight, and settles to a loping idle while hooking up. Sound uses the effects volume and respects mute and pause. Bubba appears in the cab and offers randomized country-style wisecracks for approach, hookup, lifting, hauling, setdown, and departure in speech bubbles and the cockpit banner. Lines avoid consecutive repeats for each stage, and bubbles stay inside the camera view. Each tow costs **300 credits**, including debt if necessary, and includes the existing 45-unit recovery fuel allowance so a broke pilot can still depart. Further fuel at the pad is paid. Controls and collisions are suspended during recovery; passengers, hull, and lives are preserved. Pause freezes towing, pumping, and fuel prices.

A destroyed taxi erupts in a 1.4-second explosion: a white-hot flash, expanding shockwave, fire and smoke, 64 sparks, and eight spinning pieces of its actual sprite, with brief camera shake and a synthesized bass-and-crackle blast. Flight controls lock during destruction. The retry screen appears after the effect finishes, costing exactly one life. Pausing freezes the animation. Black-hole captures keep their separate comedic suction sequence and also cost one life. With lives remaining, retry the same level with a repaired and refueled taxi, keeping earned credits and upgrades. The level's fares restart. Losing the third taxi ends the run. Main Menu and Exit are available from pause and life-loss screens. Every New Game starts at Level 1 with three lives.

## Taller worlds and sprites

Every level has 72 softly twinkling sprite stars over its painted background. An animated comet, distant spaceship, or tumbling debris cluster enters after 4-8 seconds, then another every 10-18 seconds, cycling through all three kinds with randomized directions, heights, and speeds. Ships flicker their engines and navigation lights; comets shimmer along their tails. At most three visitors appear at once. These subdued background sprites are drawn behind platforms, passengers, hazards, and the taxi, never cause collisions or appear on radar, and freeze with pause. Restarting a level clears and reseeds the scenery.

Every level is **2400 x 1440**, roughly two screens across and two screens high. The camera scrolls horizontally and vertically. Pads span over 800 vertical units, and enemies, mines, asteroids, beams, meteors, and black holes occupy different heights. The starting fuel tank holds 140 units; upgrades add 40 units each. Dispatch guidance accounts for vertical travel and avoids recommending fares whose pickup deadlines are already unrealistic.

The star gate is chosen randomly after the last delivery, at least 500 units from the taxi. Placement checks solid obstacles, platforms, the full black-hole drift area, and a connected navigation route. The gate has additive cyan/violet particles spiraling into its core, counter-rotating energy rings, orbiting sparks, and an opening shockwave. It brightens as the taxi approaches, and entry produces a brief screen-space warp burst. Particle animation freezes while paused, and old emitters are cleared when the level changes. Its two-dimensional map marker helps locate an offscreen gate. Drones break off pursuit near the exit instead of camping inside it.

The taxi, purple alien scouts, red hunter drones, and three passenger designs use a transparent sprite atlas. Passengers animate between idle and waving poses, then adopt an impatient pose near their deadline. The taxi turns with steering, has a brake-jet sprite, and retains animated exhaust and black-hole deformation. The source atlas and built-in imagegen prompt are documented in `assets/sprites/README.md`.

## Gameplay sprites

All in-world actors, platforms, service equipment, obstacles, portal hardware, and floor tiles use sprite artwork. Four hull-damage stages each have normal and braking sprites. Smoke, fireballs, sparks, thruster flames, glows, shockwaves, and accident markers use textured particles. Dynamic energy trails and the scalable HUD remain native drawing. Sprite artwork is documented in `assets/sprites/README.md`, with exact new generation prompts in `assets/sprites/gameplay-prompts.json`.

## Bitmap environment artwork

Twenty original landscape PNGs in `assets/backgrounds/` match the campaign themes, from the observation hangar and ice aurora to volcanic crust and derelict stations. They cover the complete 2400 x 1440 world with an atmospheric veil that keeps the foreground readable. Backgrounds load when a sector is first visited and are cached for revisits.

Level 3's northern lights gently ripple and shimmer across the painted sky. A localized shader follows the existing teal aurora curtains while leaving the icy terrain and distant planets stationary. Animation uses the gameplay clock, freezes during pause, and remains behind platforms, hazards, and the taxi. The original background PNG stays intact; other sectors keep their existing artwork.

`assets/sprites/frontier-props-v1.png` adds three platform styles, a fuel pump and hose, amber landing beacons, passenger terminals, steel trusses, a repair cabinet, and a fuel canister. Landing surfaces and mission markers remain aligned with the existing collision geometry. Original transparent PNGs are preserved; Godot selects trimmed atlas regions at runtime. Decorative service equipment does not block the docking lane.

Retractable cylindrical glass elevators use `assets/sprites/frontier-elevator-v1.png`, with painted steel rims, yellow trim, cyan lamps, and separate rear-cabin and glass-door layers. Open, half-closed, and closed door sprites blend during boarding, with the passenger visible between the rear and front layers. Source pixels clip at the landing-pad surface as the cabin rises or descends. The original transparent PNG and generation prompt are preserved in `assets/sprites/elevator-v1-prompt.md`.

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

The test runner defaults to the Godot 4.7.2 installation above. To use another installation, specify the executable:

```powershell
./tests/run.ps1 -GodotPath 'C:\path\to\godot.exe'
```

The runner checks import, mission integration, every level, solid collision physics, black-hole captures, lives and menus, actual application exit, passenger patience and concurrent fares, required star-gate transitions, sampled randomized gate reachability, two-screen camera movement, sprite transparency, actual inward acceleration toward black holes, animated towing, and paid fuel metering. The automated pilot uses real controls and physics to complete at least 60 deliveries and fly through all 20 randomized gates. The pilot uses actual paid service stops and repairs when needed, waiting at the pump instead of assuming instant fuel. Later-level fixtures use normal tank upgrades and the same three-life retry system as the player. A standalone later-level pilot starts with the previous sector's required credit balance, matching normal gate entry rather than an unfunded new run. Tests use isolated saves and do not change the pilot's career. Runtime errors, warnings, failed checks, and incomplete runs fail validation. Logs are under `tests/`.

`tests/preview.gd` renders the campaign overview and previews of riders, star gates, menus, and black-hole animation with a graphical rendering driver. Example images are in `tests/`.

## Source map

- `scripts/main.gd`: cockpit, boarding, fares, star gates, upgrades, lives, menus, saves.
- `scripts/fares.gd`: simultaneous riders, dispatch rules, patience, replacements, pickup choices.
- `scripts/taxi.gd`: thrusters, inertia, landings, solid rebounds, damage, capture animation, fuel.
- `scripts/tow_truck.gd`: animated rust-bucket rescue, hook and recovery field, driver speech bubbles.
- `scripts/campaign.gd`: twenty named environments, difficulty settings, pad layouts.
- `scripts/sector.gd`: enemies, solid obstacles, moving black holes, playfield-wide suction.
- `scripts/scenery.gd`: twenty procedural background compositions.
- `scripts/background_traffic.gd`: animated sprite stars and periodic decorative comets, ships, and debris.
- `scripts/audio.gd`: synthesized engine, music, and event cues.
- `scripts/radar.gd`: two-dimensional map, waiting fare markers, hazards, destination, star-gate marker.
- `scripts/world.gd`: shared level dimensions.
- `scripts/sprites.gd`: atlas regions and animation drawing.
- `assets/sprites/`: bundled sprite atlas and generation prompt.

This remains a playable prototype. Automated flights establish feasibility; human playtesting is needed for final feel, accessibility, and difficulty tuning. The soundtrack currently uses one shared synthesized music loop.


Each of the 20 levels now has an authored platform layout with broad changes to dock heights and horizontal spacing. Positions stay consistent on retries; PAD 02 remains the fuel/repair platform. Later levels still narrow the landing surfaces. `tests/platform-layouts-preview.gd` renders a contact sheet of all 20 layouts, including the service pad in cyan.


## Developer level testing

From the project directory, open any level directly in Godot's debug/editor build:

```powershell
& 'C:\software\godot\godot.exe' --path . -- --dev-level=9
```

Replace `9` with any level from **1 to 20**. Arguments after `--` are passed to the game. The selected level opens immediately with three lives, a fresh stock taxi, its real layout, and its hazards. Retries stay on that level; New Game still starts at Level 1. The window is marked DEVELOPER TEST. Career loading and saving are disabled for the entire session. Close it and launch normally to return to normal play. Release exports ignore the developer flag; invalid values also use the ordinary Level 1 main menu.

To run the automated flight pilot on just one level instead:

```powershell
& 'C:\software\godot\godot.exe' --headless --path . --script tests/flight.gd -- --trace-level=9
```
