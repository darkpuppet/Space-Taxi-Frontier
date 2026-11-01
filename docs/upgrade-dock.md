# Upgrade dock

**PAD 02** is the upgrade dock in every sector. It has its own violet armored deck, cyan runway lighting, yellow safety markings, animated guide chevrons, and a hanging **02 / UPGRADES** sign. A violet boxed **UP** marker identifies it on radar. The existing fuel pump and workshop equipment remain on the dock.

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
