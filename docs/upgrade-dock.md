# Upgrade dock

**PAD 02** is the upgrade dock in every sector. It has its own violet armored deck, cyan runway lighting, yellow safety markings, animated guide chevrons, and a hanging **02 / UPGRADES** sign. A violet boxed **UP** marker identifies it on radar. The existing fuel pump and workshop equipment remain on the dock.

Landing displays a small **PRESS ENTER TO OPEN UPGRADE SHOP** prompt (or **PRESS X** with a controller). Opening the shop pauses flight and fueling. Each selectable row shows the upgrade name, price, item sprite, current/next tier and a short description. Maxed upgrades, full hull and insufficient credits are identified in the row. Sprites reuse the existing prop atlas. Use arrow keys, rebound flight direction keys, D-pad or stick to select; Enter/Space or controller A purchases. Selection stays on the purchased item while the balance and status refresh. Escape/B returns to Pause. The existing 1–4 purchase shortcuts remain available while docked.

Land there to refuel and access the existing upgrade keys:

| Key | Purchase | Cost |
| --- | --- | --- |
| 1 | Engine | 400 CR |
| 2 | Stabilizers | 350 CR |
| 3 | Fuel tank | 300 CR |
| 4 | Repair 40 hull | 75 CR |

Its authored position, landing surface, collision bounds, and prices are unchanged. Passenger fares never spawn at or request service docks. Emergency tow still brings the taxi to PAD 02.

`scripts/upgrade_dock.gd` renders the workshop using the original generated `assets/sprites/frontier-upgrade-dock-v1.png` asset plus native signage and guide lights. Campaign pad metadata explicitly includes the `upgrades` service; rendering and radar read that service tag. The image was created with built-in imagegen as an isolated side-elevation violet/cyan workshop deck, with all machinery below its flat landing surface. The original PNG is preserved and trimmed at runtime.

A graphical run of `tests/integration.gd` saves `tests/upgrade-dock.png` for review and checks upgrade purchases and towing.

The shop engine and stabilizers use dedicated transparent sprites at `assets/sprites/shop-rocket-engine-v1.png` and `assets/sprites/shop-stabilizers-v1.png`. Built-in imagegen prompts specify a compact rocket combustion chamber with pipes and a large downward flared bell nozzle, and a pair of swept stabilizer fins with a gyroscopic hub and lateral attitude thrusters, respectively. Both use industrial yellow armor, gunmetal, cyan lights, crisp hand-painted sci-fi styling, a silhouette readable at 64 pixels, and a transparent background without text or scenery. Fuel and repair retain their existing prop-atlas sprites. `tests/controller.gd -- --shop-preview` saves a rendered shop preview to `.development/upgrade-shop.png` when run with a graphical renderer.
