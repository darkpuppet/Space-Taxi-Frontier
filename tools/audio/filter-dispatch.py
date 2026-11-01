"""Produce the shipped CB clips from local speech sources. No dependencies."""
import argparse
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
subset = parser.add_mutually_exclusive_group()
subset.add_argument('--gate-only', action='store_true')
subset.add_argument('--destination-only', action='store_true')
subset.add_argument('--pickup-only', action='store_true')
args = parser.parse_args()
jobs = [] if args.gate_only or args.destination_only else [(f'pickup-phrase-{phrase:02}-pad-{pad:02}', phrase * 10 + pad) for phrase in range(1, 7) for pad in range(1, 6)]
if not (args.destination_only or args.pickup_only):
    jobs.append(('stargate', 6))
if not (args.gate_only or args.pickup_only):
    jobs.extend((f'destination-pad-{pad:02}', pad + 10) for pad in range(1, 6))
for voice_index, voice in enumerate(('male', 'female', 'robot')):
    for suffix, pad in jobs:
        with wave.open(str(ROOT / '.development' / 'dispatch-voices' / f'{voice}-{suffix}.wav'), 'rb') as src:
            rate = src.getframerate()
            assert src.getnchannels() == 1 and src.getsampwidth() == 2
            pcm = struct.unpack('<' + 'h' * src.getnframes(), src.readframes(src.getnframes()))
        customer = suffix.startswith("destination-")
        rng = random.Random(6080 + pad + voice_index * 100)
        high_alpha = math.exp(-2 * math.pi * (90 if customer else 340) / rate)
        low_alpha = 1 - math.exp(-2 * math.pi * (6000 if customer else 2800) / rate)
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
            filtered.append(processed + rng.uniform(-.002, .002) * (1 if customer else 6))
        # Match perceived loudness across the two speakers and robot treatment.
        rms = math.sqrt(sum(v * v for v in filtered) / len(filtered))
        gain = min(2, .21 / max(.001, rms))
        peak = max(abs(v) for v in filtered)
        gain = min(gain, .90 / max(.001, peak))
        result = []
        for i in range(0 if customer else int(rate * .17)):
            t = i / rate
            result.append(rng.uniform(-1, 1) * .16 * math.sin(math.pi * t / .17))
        for i, value in enumerate(filtered):
            edge = min(1, i / (rate * .008), (len(filtered) - i) / (rate * .015))
            result.append(value * gain * edge)
        for i in range(0 if customer else int(rate * .19)):
            t = i / rate
            env = max(0, 1 - t / .19)
            chirp = math.sin(2 * math.pi * 1450 * t) * .12 if .025 < t < .085 else 0
            result.append((rng.uniform(-.15, .15) + chirp) * env)
        filename = f'customer-{voice}-{suffix.removeprefix("destination-")}-v1.wav' if customer else f'cb-{voice}-{suffix}-v2.wav'
        if suffix.startswith('pickup-phrase-'):
            filename = f'cb-{voice}-{suffix}-v3.wav'
        target = ROOT / 'assets' / 'audio' / filename
        with wave.open(str(target), 'wb') as out:
            out.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
            out.writeframes(b''.join(struct.pack('<h', round(max(-1, min(1, v)) * 30000)) for v in result))
        print(f'{voice} {suffix}: {len(result)/rate:.2f}s / {rate} Hz')
