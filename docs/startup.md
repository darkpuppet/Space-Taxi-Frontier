# Startup performance

The startup freeze came partly from generating synthesized audio and scanning every sprite-atlas pixel for alpha bounds on the main thread. The first frame also prepared gameplay graphics hidden behind the opaque title artwork.

The game now loads original synthesized waveforms from compact binary resources under `assets/audio/synth/` and uses generated crop rectangles in `scripts/atlas_regions.gd`. The title screen skips drawing the hidden world. Music, screams, clunks, and beam loops are unchanged, including loop points; the synthesis methods remain available for regeneration. PNG artwork is untouched.

Rebuild caches after modifying the relevant source:

```powershell
& 'C:\software\Godot\godot.exe' --headless --path . --script tools/cache-atlas-regions.gd
& 'C:\software\Godot\godot.exe' --headless --path . --script tools/cache-synth-audio.gd
```

`tests/startup-cache.gd` checks source-image hashes so an edited atlas cannot silently use stale crop bounds. It also checks that cached audio is sample-identical to fresh synthesis and preserves loop points.

Profile the scene through its first rendered frame with:

```powershell
& 'C:\software\Godot\godot.exe' --path . --rendering-driver opengl3 --script tools/profile-startup.gd
```

On the measured development machine, the profiled scene-to-first-frame stages totaled roughly 5.3 seconds before and 1.6 seconds after caching. Audio/UI readiness fell from 1,276 ms to 77 ms, and the four measured atlas preparations fell from 1,275 ms combined to 2 ms. These are local measurements; they exclude engine boot and are affected by disk caches and graphics-driver initialization. A first editor import can still take longer than a normal launch.
