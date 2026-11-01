# CB dispatch voice

Five bundled mono 16-bit PCM WAV clips announce platforms 1-5. Each says:

> Taxi, customer waiting at pad [one/two/three/four/five]. Over.

Source speech was synthesized locally with Windows System.Speech, Microsoft David Desktop, rate 0, volume 100. No voice imitation or downloaded recordings were used. The shipped clips require no network access, Windows speech engine, or runtime TTS support.

Processing: 340 Hz high-pass and 2800 Hz low-pass filters, tanh saturation/compression, quiet seeded static, a 170 ms push-to-talk noise burst, and a 190 ms closing squelch with a short 1450 Hz chirp. Files are 22050 Hz mono PCM and approximately five seconds each. Original engine/music/gameplay effects remain synthesized in Godot.

`scripts/dispatch_radio.gd` queues one call per new fare, selects the actual source platform, removes obsolete calls, and inserts a 450 ms transmission gap. Level changes and the main menu clear the radio. Pause freezes playback, mute discards calls, and music ducks during speech. Simultaneous pickups are announced in order. No periodic repeat calls are emitted.
