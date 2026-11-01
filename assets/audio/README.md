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

Sixty active `customer-{human,alien}-{1..6}-pad-0{1..5}-v2.wav` clips say "Platform [number], please." Both human outfits draw from six natural neural voices: Guy and Jenny (US), Ryan and Sonia (UK), William and Natasha (Australia). Green aliens draw from six separately processed voices with different pitch, warble, ring modulation, and short metallic echoes. Human recordings retain their natural pitch and timing, without radio distortion or added static. All clips are mono 24 kHz 16-bit PCM, with matched loudness and short fades.

Each species uses its own shuffled voice pool: every voice plays before a refill, and consecutive customers of that species never repeat a voice. Selection uses a separate random generator from dispatch and wording. The chosen voice remains in the queued request through interruptions. Destination requests still play once per boarded fare, ahead of pickup dispatch, with pause, mute, resets, and stargate priority preserved. Dispatcher voices are unchanged. Earlier v1 customer assets remain as references.

Regenerate with Node.js from the project root:

```powershell
npm install --prefix .development/customer-tts msedge-tts@2.1.1 mpg123-decoder@1.0.3
node tools/audio/generate-customers.cjs
```

Generation uses Microsoft's online Edge speech service through [MsEdgeTTS](https://github.com/Migushthe2nd/MsEdgeTTS). Only the five platform request lines are sent. Original neural sources are cached in ignored `.development/customer-voices/`; cached clips can be reprocessed offline. The shipped game uses bundled WAVs and needs no network, speech engine, or Node dependencies. The older PowerShell destination generator only rebuilds the inactive v1 set.

## Robot courier voice

Robot passengers have their own five `customer-robot-pad-0{1..5}-v2.wav` destination clips, separate from both randomized species pools. The voice combines a slightly lowered Guy source with a steady 92/184 Hz harmonic carrier, 9/17 ms metallic comb resonances, gentle saturation, and quantization. A dry speech component keeps the platform number intelligible. It has no alien warble. Matching normalization and fades keep it consistent with the other onboard voices.

The customer generator includes the robot by default. Regenerate just these five clips with `node tools/audio/generate-customers.cjs --robot-only`; existing cached sources allow this to run offline. Robot couriers always select this bank, while other passengers retain their shuffled human or alien voices.

## Hull impacts and energy beams

Solid contacts emit a cached, synthesized clunk independently of hull damage. Surface-normal impact speed controls volume and pitch: light taps are quiet and higher, hard strikes are louder and deeper. This covers obstacles, platform edges and undersides, landings, ground, and world boundaries, including contacts during impact damage protection. A four-player pool and a 60 ms sound cooldown limit collision chatter. Damage announcements no longer play the old generic impact tones.

Lit energy beams are passable damage volumes, draining 24 hull per second of contact independently of solid-impact protection. Swept overlap includes the taxi hull and catches fast crossings. Dark beams neither damage nor hum. A seamless synthesized electrical loop grows louder within 420 world pixels of a lit beam segment. Pause, mute, capture, menus, and shutdown silence it. All effects are generated locally and require no new audio dependencies.
