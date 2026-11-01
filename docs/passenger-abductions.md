# Passenger abductions

Starting at **Level 12**, a separate alien saucer occasionally arrives to steal a waiting fare. The first arrival is randomized between 18 and 28 seconds. Only one abductor is active at a time; after its escape, the next delay is randomized between 22 and 38 seconds. Empty or occupied pickup pads are never selected.

The saucer flies in from a random side, hovers above the passenger for 2.5 seconds, and engages a green tractor beam. The passenger rises, twists, and waves their arms for 3.2 seconds before disappearing into the saucer. A species-appropriate scream plays once at capture. The saucer accelerates away, **300 credits** are deducted once, and the abduction count increases. Credits can go negative, as with the existing passenger strike fine.

An approaching UFO triggers a pad warning and appears on radar. Landing at the passenger's platform before the lift starts sends the UFO away without a fine, allowing normal boarding. Once the beam lifts the passenger, they cannot simultaneously board, expire from impatience, or be hit as though still standing on the pad. Their pickup radio call is cancelled. The normal dispatcher creates replacement fares so three successful deliveries remain possible.

Pause freezes the sequence. Level restart, mission completion, taxi destruction, capture, and a new game cancel unfinished sequences without a fine. Abduction timing uses its own random generator. Existing patrol saucers keep their original behavior; abductor artwork reuses the existing saucer and passenger sprites with native animated tractor-beam drawing.

`scripts/abductions.gd` owns the event sequence. `scripts/fares.gd` owns fare removal/counting and boarding eligibility. `scripts/main.gd` connects warnings, credits, audio, radar, and lifecycle cleanup.

Run `tests/abductions.gd` headless for lifecycle checks, or with a graphical driver to save `tests/abductions.png` showing the mid-lift sequence. The standard `tests/run.ps1` includes the headless check.
