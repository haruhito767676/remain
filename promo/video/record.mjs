// Records scenes of the intro video: draws every frame with seek(), screenshots it through the
// Chrome DevTools Protocol, and joins the frames into an mp4 with ffmpeg.
//
//   node promo/video/record.mjs [--fps 30] [--lang en] <scene...>      -> promo/video/out/clip-<scene>-<lang>.mp4
//
// Needs Google Chrome and ffmpeg. No npm packages: Node's built-in WebSocket speaks to Chrome.
import { spawn, execFileSync } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const args = process.argv.slice(2);
const opt = (name, fallback) => { const i = args.indexOf(name); return i >= 0 ? args.splice(i, 2)[1] : fallback; };
const fps = Number(opt('--fps', 30));
const lang = opt('--lang', 'en');
const keep = args.includes('--keep') ? (args.splice(args.indexOf('--keep'), 1), true) : false;
const scenes = args;
if (!scenes.length) { console.error('usage: node record.mjs [--fps 30] [--lang en] <scene...>'); process.exit(1); }

const port = 9400 + Math.floor(Math.random() * 400);
const profile = resolve(here, 'out/.chrome-profile');
mkdirSync(profile, { recursive: true });
const browser = spawn(chrome, [
  '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files', `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`, '--force-device-scale-factor=1', '--window-size=1920,1080', 'about:blank',
], { stdio: 'ignore' });
const stop = () => { try { browser.kill(); } catch {} };
process.on('exit', stop);

async function connect() {
  for (let i = 0; i < 60; i++) {
    try {
      const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const page = pages.find((p) => p.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('Chrome did not start');
}

const ws = new WebSocket(await connect());
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let nextId = 1;
const pending = new Map();
ws.addEventListener('message', (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { const { resolve: ok, reject } = pending.get(m.id); pending.delete(m.id); m.error ? reject(new Error(m.error.message)) : ok(m.result); }
});
const send = (method, params = {}) => new Promise((ok, reject) => { const id = nextId++; pending.set(id, { resolve: ok, reject }); ws.send(JSON.stringify({ id, method, params })); });
const evaluate = async (expression) => {
  const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
  return r.result.value;
};

await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false });
await send('Page.navigate', { url: `file://${resolve(here, 'stage.html')}?mode=video&lang=${lang}` });
for (let i = 0; i < 80 && !(await evaluate('typeof seek === "function"')); i++) await new Promise((r) => setTimeout(r, 150));

mkdirSync(resolve(here, 'out'), { recursive: true });
for (const scene of scenes) {
  const duration = await evaluate(`DURATIONS['${scene}']`);
  if (!duration) throw new Error(`unknown scene ${scene}`);
  const frames = resolve(here, `out/frames-${scene}`);
  rmSync(frames, { recursive: true, force: true });
  mkdirSync(frames, { recursive: true });
  const total = Math.round(duration * fps);
  const started = Date.now();
  for (let i = 0; i < total; i++) {
    await evaluate(`seek('${scene}', ${(i / fps).toFixed(4)})`);
    const shot = await send('Page.captureScreenshot', { format: 'jpeg', quality: 94 });
    writeFileSync(`${frames}/${String(i).padStart(5, '0')}.jpg`, Buffer.from(shot.data, 'base64'));
    if (i % 60 === 0) process.stdout.write(`\r  scene ${scene}: ${i}/${total}`);
  }
  const out = resolve(here, `out/clip-${scene}-${lang}.mp4`);
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-framerate', String(fps), '-i', `${frames}/%05d.jpg`, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '17', '-movflags', '+faststart', out]);
  if (!keep) rmSync(frames, { recursive: true, force: true });
  console.log(`\r  scene ${scene}: ${total} frames in ${((Date.now() - started) / 1000).toFixed(0)} s -> ${out}`);
}
stop();
process.exit(0);
