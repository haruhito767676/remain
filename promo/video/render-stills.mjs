// Renders one key frame per scene as a PNG, for review.
//
//   node promo/video/render-stills.mjs [lang] [scene...]      -> promo/video/out/scene-<n>-<lang>.png
import { execFileSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const [lang = 'en', ...rest] = process.argv.slice(2);
const scenes = rest.length ? rest : [0, 1, '1b', '1c', '1d', 2, 3, '3b', 4, 5, 6, 7];
mkdirSync(resolve(here, 'out'), { recursive: true });

for (const scene of scenes) {
  const out = resolve(here, `out/scene-${scene}-${lang}.png`);
  execFileSync(chrome, [
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
    '--force-device-scale-factor=1', '--window-size=1920,1080', '--virtual-time-budget=4000',
    `--screenshot=${out}`, `file://${resolve(here, 'stage.html')}?scene=${scene}&lang=${lang}`,
  ], { stdio: 'ignore' });
  console.log('wrote', out);
}
