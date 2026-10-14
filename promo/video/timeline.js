// The intro video's timeline: every scene is a pure function of time, so any frame can be drawn on its own.
//
//   stage.html?mode=video      then      await seek('2', 7.5)      draws scene 2 at 7.5 s
//
// record.mjs calls seek() once per frame and takes a screenshot.

const clamp01 = (v) => Math.max(0, Math.min(1, v));
const ease = (x) => 0.5 - 0.5 * Math.cos(Math.PI * clamp01(x));  // gentle in and out
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
  const startAt = 1.5, finishAt = 11.2;
  const working = t >= startAt && t < finishAt;
  const finished = t >= finishAt;
  const menuOpen = t >= 8.0 && t < 12.6;
  // The log, the way a terminal prints it: the prompt is typed, then each line pops in whole.
  // 17 lines at full speed, then the log slows down a little before the camera leaves it.
  const lineAt = [...Array.from({ length: 17 }, (_, i) => 2.3 + i * 0.18)];
  [0.28, 0.35, 0.45, 0.55, 0.7, 0.85, 1.0].forEach((gap) => lineAt.push(lineAt[lineAt.length - 1] + gap));
  const times = [0, 1.0, ...lineAt];
  const visible = times.filter((x) => t >= x).length;
  const shown = finished ? 999 : t >= 1.0 && t < 2.0 ? 1 + (t - 1.0) : visible;
  const state = finished ? 'done' : 'short';
  const push = ease(prog(t, 5.9, 7.7)) * (1 - ease(prog(t, 15.0, 16.6)));
  const cam = { x: lerp(960, 1560, push), y: lerp(540, 150, push), scale: lerp(1, 2.3, push) };
  const nIn = easeOut(prog(t, 13.0, 13.7)), nOut = ease(prog(t, 14.9, 15.4));
  const nVis = nIn * (1 - nOut);
  const notif = $(`<div class="notif" style="opacity:${nVis.toFixed(3)};transform:translateX(${((1 - nIn) * 60 + nOut * 40).toFixed(1)}px)"><img src="assets/icons/remain.png"><div><b>${T.notif.title}</b><span>${T.notif.body}</span></div><em>now</em></div>`);
  return {
    icons: true, dock: true, cam,
    // The agent has been at it for 14 minutes: while the camera is on the menu bar, the clock runs ahead.
    menubar: { app: 'terminal', icon: working ? 'sparkles' : 'moon', active: menuOpen, clock: `Tue Oct 14  11:${String(38 + Math.round(14 * ease(prog(t, 8.6, 11.0)))).padStart(2, '0')}`, menu: menuOpen ? { status: working ? 'one' : 'idle' } : null },
    layers: [terminalWin({ x: 300, y: 130, w: 1100, h: 700, state, shown, tick: t, inactive: false })],
    notifs: nVis > 0.01 ? [notif] : [],
    black: ease(prog(t, 16.8, 18.0)) * 0.97,
  };
}

// ---------------------------------------------------------------------------------------------
// Scene 3: three agents at once, two finish and go away, the last one is stopped with Esc
// ---------------------------------------------------------------------------------------------
function scene3(t) {
  const pop = (el, p) => { el.style.opacity = p.toFixed(3); el.style.transform = `scale(${lerp(0.94, 1, p).toFixed(3)})`; return el; };
  const ideIn = easeOut(prog(t, 0.5, 1.2)), chatIn = easeOut(prog(t, 1.8, 2.5)), termIn = easeOut(prog(t, 3.1, 3.8));
  const ideOut = ease(prog(t, 13.2, 13.9)), chatOut = ease(prog(t, 15.6, 16.3));
  const ideDone = t >= 11.4, chatDone = t >= 14.0;
  const interrupted = t >= 20.0;   // the run dies with an error
  const alive = (inn, out) => inn > 0 && out < 1;
  const layers = [];
  if (alive(ideIn, ideOut)) layers.push(pop(ideWin({ x: 70, y: 84, w: 1130, h: 680, inactive: true, done: ideDone, shown: Math.max(0, (t - 1.2) / 0.95), z: 10 }), ideIn * (1 - ideOut)));
  if (alive(chatIn, chatOut)) layers.push(pop(chatWin({ x: 520, y: 130, w: 1050, h: 620, inactive: true, running: !chatDone, tick: t, z: 11 }), chatIn * (1 - chatOut)));
  // The terminal lives on: it glides to the middle and grows once the other two are gone.
  const g = ease(prog(t, 16.4, 17.8));
  const geo = { x: lerp(1000, 300, g), y: lerp(260, 130, g), w: lerp(860, 1100, g), h: lerp(560, 700, g) };
  const shown = interrupted ? 999 : t < 3.1 ? 0 : Math.min(13, 1 + (t - 3.1) * 0.7);
  if (termIn > 0) layers.push(pop(terminalWin({ ...geo, state: interrupted ? 'error' : 'short', shown, tick: Math.max(0, t - 3.1), z: 12 }), termIn));

  const app = t < 1.8 ? 'ide' : t < 3.1 ? 'chat' : 'terminal';
  const icon = t >= 23.5 ? 'moon' : 'sparkles';
  // Two looks at the menu: three agents at work, and, once the stopped one is over, "Sleeps as usual".
  const m1 = t >= 7.2 && t < 9.6, m3 = t >= 25.0 && t < 27.0;
  const menuOpen = m1 || m3;
  const status = m1 ? 'many' : 'idle';
  const pushA = ease(prog(t, 5.6, 7.2)) * (1 - ease(prog(t, 9.6, 11.2)));
  const pushC = ease(prog(t, 21.6, 23.2)) * (1 - ease(prog(t, 27.0, 28.6)));
  const push = Math.max(pushA, pushC);
  const cam = { x: lerp(960, 1560, push), y: lerp(540, 150, push), scale: lerp(1, 2.3, push) };
  const nIn = easeOut(prog(t, 23.5, 24.2)), nOut = ease(prog(t, 26.0, 26.5)), nVis = nIn * (1 - nOut);
  const notif = $(`<div class="notif" style="opacity:${nVis.toFixed(3)};transform:translateX(${((1 - nIn) * 60 + nOut * 40).toFixed(1)}px)"><img src="assets/icons/remain.png"><div><b>${T.notifStop.title}</b><span>${T.notifStop.body}</span></div><em>now</em></div>`);
  const c3 = easeOut(prog(t, 3.6, 4.3)) * (1 - ease(prog(t, 5.0, 5.5)));
  const c4 = easeOut(prog(t, 20.6, 21.3)) * (1 - ease(prog(t, 26.8, 27.4)));
  return {
    icons: true, dock: true, cam,
    menubar: { app, icon, active: menuOpen, menu: menuOpen ? { status } : null },
    layers,
    notifs: nVis > 0.01 ? [notif] : [],
    overlays: [
      text(T.cap3, 'caption', `opacity:${c3.toFixed(3)}`),
      text(T.cap4, 'caption', `opacity:${c4.toFixed(3)}`),
    ],
    black: ease(prog(t, 28.6, 29.8)) * 0.97,
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

const SCENE_FNS = { '0': scene0, '2': scene2, '3': scene3, '5': scene5 };
const DURATIONS = { '0': 6.5, '2': 18.0, '3': 29.8, '5': 12.6 };

async function seek(id, t) {
  await ensureWallpaper();
  frame(SCENE_FNS[id](t));
  scrollTerminals();
  await document.fonts.ready;
  await Promise.all([...document.images].map((i) => i.decode().catch(() => {})));
  return true;
}
Object.assign(window, { seek, DURATIONS });
