// The intro video's timeline: every scene is a pure function of time, so any frame can be drawn on its own.
//
//   stage.html?mode=video      then      await seek('2', 7.5)      draws scene 2 at 7.5 s
//
// record.mjs calls seek() once per frame and takes a screenshot.

const clamp01 = (v) => Math.max(0, Math.min(1, v));
const ease = (x) => { x = clamp01(x); return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; };
const easeOut = (x) => 1 - Math.pow(1 - clamp01(x), 3);
const prog = (t, a, b) => clamp01((t - a) / (b - a));
const lerp = (a, b, x) => a + (b - a) * x;

const stageEl = document.getElementById('stage');
const camEl = document.getElementById('camera');
let wallpaperEl = null;

async function ensureWallpaper() {
  if (wallpaperEl) return;
  wallpaperEl = $('<div class="wallpaper"></div>');
  camEl.prepend(wallpaperEl);
  await new Promise((resolve) => { const img = new Image(); img.onload = resolve; img.onerror = resolve; img.src = 'assets/wallpaper-dark.jpg'; });
}

// spec: { blur, shade, black, icons, dock, menubar, layers[], overlays[], cam: {x, y, scale} }
function frame(spec) {
  [...camEl.children].forEach((c) => { if (c !== wallpaperEl) c.remove(); });
  stageEl.querySelectorAll(':scope > .overlay').forEach((e) => e.remove());
  wallpaperEl.style.filter = spec.blur ? `blur(${spec.blur}px) saturate(1.1)` : 'none';
  if (spec.icons) camEl.appendChild(desktopIcons());
  (spec.layers || []).forEach((l) => camEl.appendChild(l));
  if (spec.dock) camEl.appendChild(dock(spec.running));
  if (spec.menubar) camEl.appendChild(menubar(spec.menubar));
  if (spec.shade) { const s = $('<div class="shade"></div>'); s.style.opacity = spec.shade; camEl.appendChild(s); }
  (spec.notifs || []).forEach((n) => camEl.appendChild(n));
  (spec.overlays || []).forEach((o) => { o.classList.add('overlay'); o.style.zIndex = 90; stageEl.appendChild(o); });
  if (spec.black) { const b = $('<div class="overlay"></div>'); b.style.cssText = `position:absolute;inset:0;background:#000;z-index:120;opacity:${spec.black}`; stageEl.appendChild(b); }
  const c = spec.cam || { x: 960, y: 540, scale: 1 };
  const tx = Math.min(0, Math.max(1920 - 1920 * c.scale, 960 - c.x * c.scale));
  const ty = Math.min(0, Math.max(1080 - 1080 * c.scale, 540 - c.y * c.scale));
  camEl.style.transform = `translate(${tx}px, ${ty}px) scale(${c.scale})`;
}

const text = (html, cls = 'caption', style = '') => $(`<div class="${cls}" style="${style}">${html}</div>`);

// ---------------------------------------------------------------------------------------------
// Scene 0: "Just remain awake." -> the "ai" lights up, becomes "AI", and the rest falls away
// ---------------------------------------------------------------------------------------------
function scene0(t) {
  const fade = easeOut(prog(t, 0.3, 1.3));
  const lit = ease(prog(t, 1.7, 2.5));            // "ai" turns blue-violet
  const pop = prog(t, 2.8, 3.5);                  // "ai" -> "AI"
  const upper = pop > 0.5;
  const scale = 1 + 0.18 * Math.sin(Math.PI * pop);
  const collapse = ease(prog(t, 4.0, 5.2));       // "Just " and " awake." fall away
  const icon = easeOut(prog(t, 4.6, 5.6));

  const h = $(`<div class="big" style="opacity:${fade};transform:translateY(calc(-50% + ${(1 - fade) * 18}px))">
    <img src="assets/icons/remain.png" style="height:170px;display:block;margin:0 auto 34px;opacity:${icon};transform:scale(${lerp(0.7, 1, icon)});filter:drop-shadow(0 20px 40px rgba(0,0,0,.5))">
    <h1 id="h1"><span class="side" id="s1">Just&nbsp;</span>rem<span class="aiwrap" style="display:inline-block;position:relative;transform:scale(${scale});transform-origin:50% 60%">
      <span style="opacity:${1 - lit}">${upper ? 'AI' : 'ai'}</span>
      <span class="ai" style="position:absolute;left:0;top:0;opacity:${lit};filter:drop-shadow(0 0 ${(lit * 26).toFixed(0)}px rgba(143,176,255,.65))">${upper ? 'AI' : 'ai'}</span></span>n<span class="side" id="s2">&nbsp;awake.</span></h1></div>`);
  stageEl.appendChild(h); // measure the side words, then collapse them
  const collapseSide = (el) => { const w = el.getBoundingClientRect().width; el.style.cssText = `display:inline-block;overflow:hidden;white-space:nowrap;vertical-align:bottom;max-width:${(w * (1 - collapse)).toFixed(1)}px;opacity:${(1 - collapse).toFixed(3)}`; };
  collapseSide(h.querySelector('#s1')); collapseSide(h.querySelector('#s2'));
  h.remove();
  return { blur: 26, shade: 0.55, overlays: [h] };
}

// ---------------------------------------------------------------------------------------------
// Scene 2: the solution. An agent works, the menu bar icon sparkles, the menu says so, it ends
// ---------------------------------------------------------------------------------------------
function scene2(t) {
  const startAt = 1.5, finishAt = 9.6;
  const working = t >= startAt && t < finishAt;
  const finished = t >= finishAt;
  const menuOpen = t >= 7.7 && t < 10.8;
  // The log, the way a terminal prints it: the prompt is typed, then each line pops in whole.
  const times = [0, 1.0, ...Array.from({ length: 21 }, (_, i) => 2.3 + i * 0.18)];
  const visible = times.filter((x) => t >= x).length;
  const shown = t >= 1.0 && t < 2.0 ? 1 + (t - 1.0) : visible;
  const state = finished ? 'done' : 'short';
  const push = ease(prog(t, 6.3, 7.3)) * (1 - ease(prog(t, 13.2, 14.2)));
  const cam = { x: lerp(960, 1560, push), y: lerp(540, 150, push), scale: lerp(1, 2.3, push) };
  const nIn = easeOut(prog(t, 11.2, 11.8)), nOut = ease(prog(t, 12.8, 13.3));
  const nVis = nIn * (1 - nOut);
  const notif = $(`<div class="notif" style="opacity:${nVis.toFixed(3)};transform:translateX(${((1 - nIn) * 60 + nOut * 40).toFixed(1)}px)"><img src="assets/icons/remain.png"><div><b>${T.notif.title}</b><span>${T.notif.body}</span></div><em>now</em></div>`);
  return {
    icons: true, dock: true, cam,
    menubar: { app: 'terminal', icon: working ? 'sparkles' : 'moon', active: menuOpen, menu: menuOpen ? { status: working ? 'one' : 'idle' } : null },
    layers: [terminalWin({ x: 300, y: 130, w: 1100, h: 700, state, shown, tick: t, inactive: false })],
    notifs: nVis > 0.01 ? [notif] : [],
    black: ease(prog(t, 14.6, 15.8)) * 0.97,
  };
}

// ---------------------------------------------------------------------------------------------
// Scene 5: the lid closes and the Mac keeps going; then why it stops by itself
// ---------------------------------------------------------------------------------------------
function scene5(t) {
  const beta = lerp(105, 0, ease(prog(t, 0.8, 3.4)));
  const dim = ease(prog(t, 10.4, 11.2));          // the light goes out: it has stopped
  const screen = clamp01((beta - 6) / 22);
  const c5 = easeOut(prog(t, 3.8, 4.4)) * (1 - ease(prog(t, 6.2, 6.7)));
  const c5b = easeOut(prog(t, 6.9, 7.5));
  const pill = (a) => easeOut(prog(t, a, a + 0.5));
  const pills = T.pills.map((p, i) => `<span style="opacity:${pill(7.6 + i * 0.6).toFixed(2)};transform:translateY(${((1 - pill(7.6 + i * 0.6)) * 14).toFixed(1)}px)">${p}</span>`).join('');
  return {
    blur: 26, shade: 0.5,
    layers: [laptop3d(beta, { leakMul: 1 - dim, screen })],
    overlays: [
      text(T.cap5, 'caption', `bottom:130px;opacity:${c5.toFixed(3)}`),
      text(`${T.cap5b}<div class="pills">${pills}</div>`, 'caption', `bottom:110px;opacity:${c5b.toFixed(3)}`),
    ],
    black: ease(prog(t, 11.6, 12.6)) * 0.97,
  };
}

const SCENE_FNS = { '0': scene0, '2': scene2, '5': scene5 };
const DURATIONS = { '0': 6.5, '2': 15.8, '5': 12.6 };

async function seek(id, t) {
  await ensureWallpaper();
  frame(SCENE_FNS[id](t));
  scrollTerminals();
  await document.fonts.ready;
  await Promise.all([...document.images].map((i) => i.decode().catch(() => {})));
  return true;
}
Object.assign(window, { seek, DURATIONS });
