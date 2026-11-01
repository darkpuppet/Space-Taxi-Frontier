// Install generation dependencies (the game itself needs none):
// npm install --prefix .development/customer-tts msedge-tts@2.1.1 mpg123-decoder@1.0.3
// node tools/audio/generate-customers.cjs
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const root = path.resolve(__dirname, '../..');
const deps = path.join(root, '.development/customer-tts/node_modules');
const { MsEdgeTTS, OUTPUT_FORMAT } = require(path.join(deps, 'msedge-tts'));
const voices = ['en-US-GuyNeural', 'en-US-JennyNeural', 'en-GB-RyanNeural',
    'en-GB-SoniaNeural', 'en-AU-WilliamNeural', 'en-AU-NatashaNeural'];
const numbers = ['one', 'two', 'three', 'four', 'five'];

function wav(samples, rate, alien = -1, robot = false) {
    const ratios = [0.73, 1.32, 0.88, 1.17, 0.65, 1.43];
    const ratio = robot ? 0.90 : alien < 0 ? 1 : ratios[alien];
    const output = new Float32Array(Math.floor(samples.length / ratio));
    for (let i = 0; i < output.length; i++) {
        const t = i / rate;
        const position = Math.min(samples.length - 1, i * ratio +
            (alien < 0 ? 0 : Math.sin(t * Math.PI * 2 * (7 + alien * 2)) * 8));
        const at = Math.max(0, Math.floor(position));
        const fraction = Math.max(0, position - at);
        let value = samples[at] * (1 - fraction) + samples[Math.min(at + 1, samples.length - 1)] * fraction;
        if (alien >= 0) {
            const echo = samples[Math.max(0, at - Math.round(rate * (0.018 + alien * 0.007)))];
            value = value * (0.72 + 0.28 * Math.sin(t * Math.PI * 2 * (38 + alien * 19))) + echo * 0.18;
        }
        if (robot) {
            // Steady harmonic carrier and comb resonances: a friendly vocoder-like
            // courier voice. Retain dry speech so platform numbers stay clear.
            const carrier = Math.sin(t * Math.PI * 2 * 92) * 0.72 + Math.sin(t * Math.PI * 2 * 184) * 0.28;
            const echo = delay => samples[Math.max(0, at - Math.round(rate * delay))];
            value = value * (0.48 + carrier * 0.52) + echo(0.009) * 0.22 - echo(0.017) * 0.12;
            value = Math.round(Math.tanh(value * 1.8) * 1024) / 1024;
        }
        output[i] = value * Math.min(1, i / (rate * 0.008), (output.length - i) / (rate * 0.015));
    }
    let peak = 0.001, energy = 0;
    for (const value of output) { peak = Math.max(peak, Math.abs(value)); energy += value * value; }
    const gain = Math.min(0.89 / peak, 0.18 / Math.max(0.001, Math.sqrt(energy / output.length)));
    const data = Buffer.alloc(44 + output.length * 2);
    data.write('RIFF'); data.writeUInt32LE(data.length - 8, 4); data.write('WAVEfmt ', 8);
    data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(1, 22);
    data.writeUInt32LE(rate, 24); data.writeUInt32LE(rate * 2, 28);
    data.writeUInt16LE(2, 32); data.writeUInt16LE(16, 34); data.write('data', 36);
    data.writeUInt32LE(output.length * 2, 40);
    output.forEach((value, i) => data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, value * gain)) * 32767), 44 + i * 2));
    return data;
}

(async () => {
    const { MPEGDecoder } = await import(pathToFileURL(path.join(deps, 'mpg123-decoder/index.js')));
    const decoder = new MPEGDecoder();
    await decoder.ready;
    const cache = path.join(root, '.development/customer-voices');
    fs.mkdirSync(cache, { recursive: true });
    for (const [index, voice] of voices.entries()) {
        const robotOnly = process.argv.includes('--robot-only');
        if (robotOnly && index !== 0) continue;
        const tts = new MsEdgeTTS({ connectionTimeoutMs: 15000, synthesisTimeoutMs: 30000 });
        try {
            for (let pad = 1; pad <= 5; pad++) {
                const source = path.join(cache, `${voice}-${pad}.mp3`);
                if (!fs.existsSync(source)) {
                    await tts.setMetadata(voice, OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);
                    const { audioFilePath } = await tts.toFile(cache, `Platform ${numbers[pad - 1]}, please.`);
                    fs.renameSync(audioFilePath, source);
                }
                await decoder.reset();
                const decoded = decoder.decode(fs.readFileSync(source));
                if (decoded.errors.length || !decoded.samplesDecoded) throw new Error(`Invalid speech: ${source}`);
                for (const kind of robotOnly ? [] : ['human', 'alien']) {
                    const target = path.join(root, 'assets/audio', `customer-${kind}-${index + 1}-pad-0${pad}-v2.wav`);
                    fs.writeFileSync(target, wav(decoded.channelData[0], decoded.sampleRate, kind === 'alien' ? index : -1));
                    console.log(path.basename(target));
                }
                if (index === 0) {
                    const target = path.join(root, 'assets/audio', `customer-robot-pad-0${pad}-v2.wav`);
                    fs.writeFileSync(target, wav(decoded.channelData[0], decoded.sampleRate, -1, true));
                    console.log(path.basename(target));
                }
            }
        } finally { tts.close(); }
    }
    decoder.free();
})().catch(error => { console.error(error); process.exitCode = 1; });
