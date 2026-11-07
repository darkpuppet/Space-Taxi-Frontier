# Taxi dashboard

The driving HUD sits along the bottom of the screen, leaving the windscreen clear.

- Fuel and health are sprite-based analog instruments with live needles and no numeric readouts. Fuel is normalized to the upgraded tank capacity; health shows remaining hull from full when undamaged to empty when destroyed, with a red warning zone at the low end.
- Below 20 fuel units, a small amber gas-can icon flashes fully inside the black fuel gauge face, below and right of the needle pivot, once per second. It matches the audio warning threshold and leaves the FUEL caption visible. It clears at 20 or above; pausing freezes the flash.
- The 1960s automotive fascia combines taxi-yellow painted metal, a black leather pad, chrome instrument rings and orange-red needles.
- Fare and balance sit in raised metal tabs above the fuel and health gauges. Their mechanical drums scroll through intervening digits in either direction over 0.45 seconds, including carries; updates queue until an active roll finishes. Fare includes the remaining speed bonus and clears to zero after drop-off. Balance supports debt.
- The former fare, account and odometer boxes, plus the FOR HIRE, sector/lives and TOTAL DISTANCE captions, are removed. Distance still persists with career saves across sectors and retries, and resets for a new run. Towing, teleports and stationary time add no distance; prior world-pixel totals migrate once into calibrated meters.
- Pickup, destination and navigation instructions remain beside the meters.
- A portrait phone mounted to the right side of the dash shows the live sector map, target route, distance, waiting fares, hazards and star gate.
- The ? button or F1 opens a paused handbook with controls, sector progress and service information. Resume or Escape returns to driving.

The fare calculation and economy are unchanged: the displayed fare uses the same calculation as the drop-off payment.

The dashboard fascia is 150 pixels tall with 104-pixel gauges, raised fare/balance tabs, and a lowered phone mount. The camera follows the taxi at the center of the area above the dashboard and can scroll below the world's lower boundary. The tabs align over their gauges and leave the central driving view clear.

Instrument artwork lives in `assets/sprites/dashboard-1960s-v1.png`; the yellow fascia is drawn from `assets/sprites/dashboard-yellow-v1.png`. Edit prompts are recorded alongside the atlases. Gauge faces and needles are separate atlas regions so gameplay values remain dynamic. The previous atlases remain available.

## Distance scale

The taxi sprite is 74 world pixels long. We assume a 4.5-meter taxi as a design scale, giving 4.5 / 74 = 0.06081081 meters per world pixel. A kilometer is therefore 16,444.444 world pixels, or 222.222 taxi lengths. This uses world coordinates, so resizing the window does not change mileage.

`scripts/world.gd` owns this scale. Mileage, navigation distances, altitude, speed and the phone's route distance all use it. Physics and sector geometry remain in world pixels. Saves store physical meters and a scale version so loading does not convert an already migrated total twice.
