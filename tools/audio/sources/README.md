# Aluminum-can crushing recording

`aluminum-can-crunch.wav` is decoded from the public high-quality preview of
**soda - can - crunch 03.wav** by **Anthousai**:

- Source: https://freesound.org/people/Anthousai/sounds/398982/
- Download: https://cdn.freesound.org/previews/398/398982_5923045-hq.mp3
- License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/
- Recording: an empty aluminum soda can crushed by hand, recorded on a Tascam DR-40.
- Downloaded November 6, 2026. MP3 SHA256:
  `e1dc27540295f5aea377468236b25b2c1debb5228c2e99bcf02ab323411c66bf`.

The available high-quality preview decodes to 48 kHz stereo. This bundled source
is 16-bit PCM decoded with `mpg123-decoder@1.0.3`; it is not the original 96 kHz,
24-bit master. The source's lossy compression cannot be undone by saving as WAV.

`tools/audio/generate-crumple.gd` trims the recorded crunch, uses small pitch and
gain variations, and places six squeezes at the animation's shared buckle times.
The final game asset is `assets/audio/taxi-can-crumple.wav`, 48 kHz stereo PCM.
There are no synthetic tones or generated metal noises in this effect.
