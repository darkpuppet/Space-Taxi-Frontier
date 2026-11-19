// Optional PNG previews: requires the sharp Node package.
const sharp = require('sharp');
const path = require('node:path');

async function main() {
  for (const number of ['05', '20']) {
    const base = path.join(__dirname, '..', 'docs', 'level-diagrams', `level-${number}`);
    await sharp(`${base}.svg`).resize(1550).png().toFile(`${base}-preview.png`);
    console.log(`Rendered level ${number}`);
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
