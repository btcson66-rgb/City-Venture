// Rasterize the editable SVG sources directly at native and 4x resolution.
const fs = require('fs');
const path = require('path');
const sharp = require(process.env.CITY_SHARP || 'C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../..');
async function main() {
  const jobs = JSON.parse(fs.readFileSync(path.join(root, 'docs/art_sources/custom_character_20261001/render_jobs.json')));
  for (const job of jobs) {
    const sourcePath = path.resolve(root, job.source);
    const source = Buffer.from(fs.readFileSync(sourcePath, 'utf8').replace(/href="([^"#]+\.png)"/g, (_, relative) => {
      const contents = fs.readFileSync(path.resolve(path.dirname(sourcePath), relative));
      return 'href="data:image/png;base64,' + contents.toString('base64') + '"';
    }));
    for (const factor of [1, 4]) {
      const target = path.join(root, 'game/assets', factor === 4 ? 'world_detail' : '', job.key + '.png');
      fs.mkdirSync(path.dirname(target), {recursive: true});
      await sharp(source).resize(job.size[0] * factor, job.size[1] * factor).png().toFile(target);
    }
  }
  console.log(`Rendered ${jobs.length} layer sheets at native and 4x sizes.`);
}
main().catch(e => {console.error(e); process.exit(1);});
