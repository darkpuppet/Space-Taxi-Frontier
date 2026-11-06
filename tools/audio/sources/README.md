# Aluminum-can crushing recording

`aluminum-can-crunch.wav` is decoded from the public high-quality preview of
**crushing aluminium can - 6** by **FOSSarts**:

- Source: https://freesound.org/people/FOSSarts/sounds/761713/
- Download: https://cdn.freesound.org/previews/761/761713_14631530-hq.mp3
- License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/
- Recording: an empty aluminum soda can being crushed, recorded on a Zoom H1 essential.
- Downloaded November 6, 2026. MP3 SHA256:
  `cc5b3627b336f0018cc647dd3c8758f08a4b00db66b54732323a72093470415b`.

The bundled source is 48 kHz stereo, 16-bit PCM decoded with
`mpg123-decoder@1.0.3` from the available high-quality MP3 preview. It is not the
original 96 kHz, 32-bit master; saving as WAV does not undo lossy compression.

`tools/audio/generate-crumple.gd` takes one continuous 2.1-second passage starting
at 0.18 seconds, normalizes its level, and fades the boundaries. Pitch, speed,
and the natural crinkles between the main collapses are preserved. There are no
repeated fragments, synthetic tones, or added resonances in this effect.

The game plays `assets/audio/taxi-can-crumple.wav` (48 kHz stereo PCM), lowers the
music during capture, and plays no simultaneous suction jingle.
