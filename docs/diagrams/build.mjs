// Builds every diagram in light and dark from src/NN-*.mjs.
//   npm install        (once; pulls the pinned eraser-diagrams CLI)
//   npm run build      (all diagrams)   npm run build -- 02   (just one)
// Output: NN-name.png (light) and NN-name-dark.png (dark) next to this file.
import { readdirSync, readFileSync, mkdirSync, writeFileSync, renameSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { normalizeFetchedIcon } from '@eraserlabs/diagram-templates/svg-transforms';
import { THEMES } from './src/club.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const only = process.argv.slice(2);
const sources = readdirSync(join(here, 'src'))
  .filter((f) => /^\d\d-.*\.mjs$/.test(f))
  .filter((f) => only.length === 0 || only.some((n) => f.startsWith(n)));

const tmp = join(here, '.build');
rmSync(tmp, { recursive: true, force: true });
mkdirSync(tmp);

// Official Google Cloud icons live in icons/ (see icons/README.md). The renderer checks its
// icon cache before the network, so seeding the cache makes gcloud-* names resolve locally.
const iconCache = join(tmp, 'icons');
mkdirSync(iconCache);
for (const f of readdirSync(join(here, 'icons')).filter((f) => f.endsWith('.svg'))) {
  const name = f.replace(/\.svg$/, '');
  writeFileSync(join(iconCache, f), normalizeFetchedIcon(readFileSync(join(here, 'icons', f), 'utf8'), name));
}

const jobs = [];
for (const file of sources) {
  const name = file.replace(/\.mjs$/, '');
  const { build } = await import(join(here, 'src', file));
  for (const theme of Object.keys(THEMES)) {
    const out = theme === 'light' ? name : `${name}-dark`;
    writeFileSync(join(tmp, `${out}.json`), JSON.stringify(build(THEMES[theme]), null, 2));
    jobs.push(out);
  }
}

// --transparent keeps the renderer's fixed outer padding see-through, so the
// dark diagrams don't get a white frame. Each diagram paints its own background.
execFileSync('npx', ['eraser-diagrams', 'render', ...jobs.map((j) => join(tmp, `${j}.json`)),
  '--scale', '2', '--transparent', '--unknown-icon', 'error', '--icon-cache-dir', iconCache, '--out-dir', tmp, '-q'], { cwd: here, stdio: 'inherit' });

for (const j of jobs) renameSync(join(tmp, `${j}.png`), join(here, `${j}.png`));
rmSync(tmp, { recursive: true, force: true });
console.log(`built ${jobs.length} images: ${jobs.join(', ')}`);
