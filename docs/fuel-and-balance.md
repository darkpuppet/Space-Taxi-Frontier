# Fuel, balance targets, and sector transitions

The taxi consumes **0.10 fuel per second** while active, even when docked or coasting. Lift thrusters consume an additional **2.7 per second**, with the existing steering and braking costs unchanged. Pausing, destruction, and black-hole capture stop idle consumption.

Advancement requires at least **three successful deliveries** and the sector's required **current credit balance**. Upgrades, repairs, tow charges, and passenger fines reduce that balance. Extra fares continue spawning if three deliveries are insufficient. Spending below the target after unlocking a gate closes it and resumes dispatch; gate entry also rechecks the balance.

Targets live in `scripts/campaign.gd`, in `required_balance`. With zero-based sector index `n`, the default is `750 * (n + 1) + 100 * n * (n + 1)`: 750 CR in Level 1, 1,700 in Level 2, 2,850 in Level 3, and 53,000 in Level 20. The HUD and pause menu display the target.

Star-gate travel carries the taxi's exact fuel and hull into the next sector. Opening a gate no longer grants departure fuel. Dock at PAD 02 for service when necessary. A new game, a developer level launch, or a replacement taxi after losing a life still starts with full fuel and hull.

`tests/economy.gd` covers idle versus thruster consumption, pausing, balance locks, extra fares, spending after gate unlock, and resource carryover.
