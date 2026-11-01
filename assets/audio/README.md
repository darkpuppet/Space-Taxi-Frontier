# CB dispatch voices

The active pickup set contains ninety `cb-{male,female,robot}-pickup-phrase-0{1..6}-pad-0{1..5}-v3.wav` clips: three voices, six complete phrases each, and all five pad numbers.

1. Fare waiting at pad [number]. Over.
2. Customer at pad [number]. Over.
3. You have a customer at pad [number]. Over.
4. Taxi, pickup requested at pad [number]. Over.
5. Passenger needs a ride at pad [number]. Over.
6. Dispatch to taxi. Head to pad [number] for a fare. Over.

Each level randomly chooses one of three dispatchers with equal probability and retains that voice through retries. Pickup wording is drawn from shuffled sets of six, avoiding immediate repeats even between sets. The phrase stays attached to its fare across queue updates and interruptions. A separate random generator for wording keeps it independent of the level's voice selection. Starting a new game clears the selection; entering another level makes a fresh voice draw, which may select the same voice again.

Pickup clips last approximately 3-5 seconds at the established faster speech rate. Earlier pickup versions remain preserved but are no longer used at runtime. Regenerate just the pickup set with `./tools/audio/generate-dispatch.ps1 -PickupOnly` and `py tools/audio/filter-dispatch.py --pickup-only`.

Male speech uses Windows System.Speech Microsoft David Desktop; female speech uses Microsoft Zira Desktop. Both use speech rate 2 and volume 100. The robot uses David with 72 Hz ring modulation blended with the dry speech, a 12 ms metallic echo, and quantization. All clips are synthesized locally, without downloaded recordings or voice imitation. The shipped game needs no speech engine or network connection.

All voices retain CB processing: 340 Hz high-pass and 2800 Hz low-pass filters, tanh saturation/compression, quiet seeded static, a 170 ms push-to-talk burst, and a 190 ms closing squelch with a short 1450 Hz chirp. Loudness is matched with peak limiting. Files are 22050 Hz mono 16-bit PCM. The original `cb-pickup-pad-*.wav` assets are preserved for reference and are no longer used at runtime.

To regenerate on Windows with both voices installed, run from the project root:

```powershell
./tools/audio/generate-dispatch.ps1
py tools/audio/filter-dispatch.py
```

Intermediate sources stay in the ignored `.development/dispatch-voices/` directory. The Python filter uses only the standard library. Godot imports the completed WAVs.

`scripts/dispatch_radio.gd` queues one call per new fare, selects the correct source platform and the level's voice, removes obsolete calls, and inserts a 450 ms transmission gap. Level changes and the main menu clear pending speech. Pause freezes playback, mute discards calls, and music ducks during speech. Simultaneous pickups are announced in order. No periodic repeat calls are emitted. Original engine/music/gameplay effects remain synthesized in Godot.


## Passenger accident screams

Passenger impacts play the existing squish plus a brief locally synthesized cartoon scream. Humans use a 440 ms vowel-shaped yelp; aliens use a 480 ms higher warbling yelp. Both have vocal harmonics/formants, a quick attack, a soft release, and small per-impact pitch variation. These are original synthesized effects with no external recordings. Both waveforms are cached before gameplay so an accident does not synthesize audio during flight. Each killed passenger triggers the effect only once. The sounds respect the existing master mute.

## Stargate announcement

Three `cb-{male,female,robot}-stargate-v2.wav` clips say: "Taxi, star gate is open. Head for the gate. Over." They use the same speed, CB filtering, static and squelch as pickup calls. The current level's dispatcher announces the gate once when it opens, replacing obsolete pickup speech. Pause and mute apply to the transmission; level restart/new game resets its announcement state. Each clip lasts about five seconds and works offline.

The generation tools now include gate clips by default. Use `./tools/audio/generate-dispatch.ps1 -GateOnly` followed by `py tools/audio/filter-dispatch.py --gate-only` to regenerate only these three assets.

## Onboard destination requests

Fifteen `customer-{male,female,robot}-pad-0{1..5}-v1.wav` clips say "Platform [number], please." Boarding selects the actual destination and a voice matching the character: orange-suit human uses male, blue-suit human uses female, and green alien uses the metallic robot treatment. This does not change the level's CB dispatcher voice. Requests last approximately 2.2 seconds and play once per boarded fare, ahead of pickup dispatch; other pickup calls resume afterward. Pause, mute, level resets, and stargate priority all apply.

These in-cab clips use a broader 90-6000 Hz voice band with very light noise and no CB opening/closing burst. Sources use the same local speech generation at rate 2. The alien variant retains the metallic modulation. Generate only these clips with `./tools/audio/generate-dispatch.ps1 -DestinationOnly` and `py tools/audio/filter-dispatch.py --destination-only`.
