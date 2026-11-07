# Fuel, balance targets, and sector transitions

The taxi consumes **0.50 fuel per second** while active, even when docked or coasting. A full stock tank lasts **4 minutes 40 seconds** at idle, keeping pressure on the player to find the next fare. Lift thrusters consume an additional **2.7 per second**, with the existing steering and braking costs unchanged. Pausing, destruction, and black-hole capture stop idle consumption.

An empty tank disables powered steering, thrust and braking. The taxi retains its momentum and falls under gravity, with normal collisions and impact damage. Recovery waits until it has remained stationary for half a second; an empty taxi's low-speed ground bounces settle instead of continuing indefinitely. The truck then approaches the final resting position and the usual tow charge applies. Pressing T cannot bypass the settling wait when fuel is empty. Pause freezes the wait; a funded taxi already at the fuel pump refuels without a tow.

Advancement requires at least **three successful deliveries** and the sector's required **current credit balance**. Upgrades, repairs, tow charges, and passenger fines reduce that balance. Extra fares continue spawning if three deliveries are insufficient. Spending below the target after unlocking a gate closes it and resumes dispatch; gate entry also rechecks the balance.

Targets live in `scripts/campaign.gd`, in `required_balance`. With zero-based sector index `n`, the default is `750 * (n + 1) + 100 * n * (n + 1)`: 750 CR in Level 1, 1,700 in Level 2, 2,850 in Level 3, and 53,000 in Level 20. The HUD and pause menu display the target.

Star-gate travel carries the taxi's exact fuel and hull into the next sector. Opening a gate no longer grants departure fuel. Dock at PAD 02 for service when necessary. A new game, a developer level launch, or a replacement taxi after losing a life still starts with full fuel and hull.

`tests/economy.gd` covers idle versus thruster consumption, pausing, balance locks, extra fares, spending after gate unlock, and resource carryover.
