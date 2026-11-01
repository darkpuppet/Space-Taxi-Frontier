# Controller support

The game uses Godot's standard gamepad mappings, with Xbox-style button names below. PlayStation and other recognized pads use their equivalent positions.

| Control | Action |
| --- | --- |
| Left stick or D-pad left/right | Steer |
| A (south face button) or right trigger | Lift thrusters |
| B (east face button) or left trigger | Brake |
| Start / Menu | Pause or resume; start a game from the title screen |
| X (west face button), docked at PAD 02 | Open workshop purchases |
| Y (north face button) | Emergency tow, once per shift |
| Back / View | Toggle mute during flight |
| D-pad or left stick in menus | Move focus; adjust focused sliders |
| A in menus | Activate the focused control |
| B in menus | Back/cancel; resume from Pause |

The Pause menu also offers a confirmed Retry action that uses one life. Controller settings retain the saved flight dead zone. Keyboard rebinding preserves gamepad mappings. Prompts switch when a controller or keyboard is used. Disconnecting the active controller during normal flight automatically pauses the game.

The workshop is paused while purchasing upgrades. Its buttons use the same prices and validation as keyboard shortcuts. B returns to Pause; Start resumes flight.

Leaderboard name entry includes a focusable on-screen A-Z/0-9 keyboard, Space and Delete. Select letters with D-pad/stick and A, then select Save. The first on-screen character replaces the prefilled name; typing with a physical keyboard also remains supported.

`tests/controller.gd` injects gamepad events through Godot's input system and checks actual steering, triggers, menu activation, tow, workshop purchase, disconnect pausing, and leaderboard name entry. It does not require a physically attached controller. A graphical run saves a name-entry preview under `tests/`.
