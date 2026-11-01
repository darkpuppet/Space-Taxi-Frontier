"""Produce the shipped CB clips from local speech sources. No dependencies."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
for voice_index, voice in enumerate(('male', 'female', 'robot')):
    for pad in range(1, 6):
        with wave.open(str(ROOT / '.development' / 'dispatch-voices' / f'{voice}-pad-{pad:02}.wav'), 'rb') as src:
            rate = src.getframerate()
            assert src.getnchannels() == 1 and src.getsampwidth() == 2
            pcm = struct.unpack('<' + 'h' * src.getnframes(), src.readframes(src.getnframes()))
        rng = random.Random(6080 + pad + voice_index * 100)
        high_alpha = math.exp(-2 * math.pi * 340 / rate)
        low_alpha = 1 - math.exp(-2 * math.pi * 2800 / rate)
        high = low = previous = 0.0
        filtered = []
        delay = max(1, round(rate * .012))
        for i, value in enumerate(pcm):
            sample = value / 32768
            high = high_alpha * (high + sample - previous)
            previous = sample
            low += low_alpha * (high - low)
            processed = math.tanh(low * 5.5) * .67
            if voice == 'robot':
                # Parallel metallic ring modulation retains a clear dry voice.
                carrier = math.sin(2 * math.pi * 72 * i / rate)
                echo = pcm[i - delay] / 32768 if i >= delay else 0
                processed = processed * (.70 + .30 * carrier) + echo * .14
                processed = round(processed * 512) / 512
            filtered.append(processed + rng.uniform(-.012, .012))
        # Match perceived loudness across the two speakers and robot treatment.
        rms = math.sqrt(sum(v * v for v in filtered) / len(filtered))
        gain = min(2, .21 / max(.001, rms))
        peak = max(abs(v) for v in filtered)
        gain = min(gain, .90 / max(.001, peak))
        result = []
        for i in range(int(rate * .17)):
            t = i / rate
            result.append(rng.uniform(-1, 1) * .16 * math.sin(math.pi * t / .17))
        for i, value in enumerate(filtered):
            edge = min(1, i / (rate * .008), (len(filtered) - i) / (rate * .015))
            result.append(value * gain * edge)
        for i in range(int(rate * .19)):
            t = i / rate
            env = max(0, 1 - t / .19)
            chirp = math.sin(2 * math.pi * 1450 * t) * .12 if .025 < t < .085 else 0
            result.append((rng.uniform(-.15, .15) + chirp) * env)
        target = ROOT / 'assets' / 'audio' / f'cb-{voice}-pad-{pad:02}-v2.wav'
        with wave.open(str(target), 'wb') as out:
            out.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
            out.writeframes(b''.join(struct.pack('<h', round(max(-1, min(1, v)) * 30000)) for v in result))
        print(f'{voice} pad {pad}: {len(result)/rate:.2f}s / {rate} Hz')
