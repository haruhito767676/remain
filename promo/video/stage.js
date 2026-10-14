// The intro video's stage: a recreated macOS desktop with a camera.
//
//   stage.html?scene=2&lang=en        one key frame of a scene (for reference images and review)
//
// Every word that appears in the video is in TEXT below, so the wording can be reviewed in one place.

const TEXT = {
  en: {
    tagline: ['Just rem', 'ai', 'n awake.'],
    // On-screen captions
    cap1a: 'Sleep cuts the run.',
    cap1b: 'Work done. But the Mac still stays awake.',
    cap1c: 'All night…',
    cap1d: '…until the battery gives out.',
    lowBattery: { title: 'Low Battery', body: '10% battery remaining.' },
    cap2: 'Awake only while an agent works.',
    cap3: 'Whichever you use. Several at once.',
    cap4: 'Stopped halfway? It notices.',
    cap5: 'Close the lid. It keeps going.',
    cap5b: 'And it stops by itself when…',
    pills: ['It gets too hot', 'The battery runs low', 'Time is up'],
    cap6: 'Stored only on your Mac.',
    finale: 'Now, remain asleep.',
    download: 'Download remAIn · macOS 14+ · MIT',
    // The desktop
    clock: 'Tue Oct 14  11:38',
    menus: {
      terminal: ['Terminal', 'Shell', 'Edit', 'View', 'Window', 'Help'],
      ide: ['Antigravity IDE', 'File', 'Edit', 'Selection', 'View', 'Go', 'Run', 'Terminal', 'Window', 'Help'],
      chat: ['ChatGPT', 'File', 'Edit', 'View', 'Window', 'Help'],
      finder: ['Finder', 'File', 'Edit', 'View', 'Go', 'Window', 'Help'],
    },
    // remAIn's menu
    menuStatus: { idle: 'Sleeps as usual', one: 'An agent is working', many: '3 agents working' },
    menuItems: ['Keep Awake', 'Keep Running with Lid Closed', 'Settings…', 'About remAIn', 'Quit remAIn'],
    notif: { title: 'An agent finished its work', body: 'web-app · took 14m 32s' },
    // Window contents (invented)
    term: {
      title: 'web-app — claude — 100×30',
      header: 'Claude Code',
      path: '~/Projects/web-app',
      ask: 'Add rate limiting to the API and make the tests pass',
      steps: ['Reading src/api/middleware.ts', 'Editing src/api/rateLimit.ts  (+42 −3)', 'Running npm test'],
      result: '46 passed · 2 failed',
      fixing: 'Fixing tests/rateLimit.test.ts',
      working: 'Working… (2h 41m · esc to interrupt)',
      workingShort: 'Working… (3m 12s · esc to interrupt)',
      interrupted: 'Interrupted · What should Claude do instead?',
      done: 'Worked for 14m 32s',
      footer: '? for shortcuts · ← for agents',
      caffeinate: 'caffeinate -i',
      caffeinateTitle: 'Terminal — caffeinate',
    },
    ide: { tab: 'rateLimit.ts', agent: 'Agent', done: 'Finished. 4 files changed.', steps: ['Read middleware.ts', 'Add a token bucket per client', 'Wire it into the router', 'Run the test suite'], input: 'Ask anything…', status: 'Main · 0 problems · TypeScript' },
    chat: {
      side: ['New chat', 'Projects', 'Recent', 'Fix flaky login test', 'Add rate limiting', 'Write the API docs'],
      history: ['Fix flaky login test', 'Add rate limiting', 'Write the API docs', 'Migrate to Postgres 16', 'Speed up the CI build', 'Refactor the auth module',
        'Add dark mode', 'Upgrade dependencies', 'Explain this stack trace', 'Draft the release notes', 'Debug the upload timeout', 'Clean up unused CSS'],
      done: 'Done. All tests pass.',
      title: 'Codex',
      user: 'Add rate limiting to the API and make the tests pass',
      lead: 'I added a token bucket per client and wired it into the router. Changes:',
      bullets: ['src/api/rateLimit.ts', 'src/api/router.ts', 'tests/rateLimit.test.ts'],
      block: 'npm install\nnpm test',
      running: 'Running the tests…',
      composer: 'Work with Codex',
    },
  },
};

const $ = (html) => { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstChild; };
const params = new URLSearchParams(location.search);
const lang = params.get('lang') || 'en';
const T = TEXT[lang] || TEXT.en;

// ---------- Building blocks ----------

function menubar({ app, icon, active, menu, battery = 82, clock = T.clock }) {
  const names = T.menus[app];
  const left = names.map((n, i) => `<span class="${i === 0 ? 'appname' : ''}">${n}</span>`).join('');
  const status = icon ? `<span class="slot status ${active ? 'active' : ''}" id="status"><img src="assets/symbols/${icon}.png">${menu ? menuHtml(menu) : ''}</span>` : '';
  return $(`<div class="menubar"><div class="left"><span class="apple">&#xF8FF;</span>${left}</div>
    <div class="right">${status}
      <span class="slot"><img src="assets/symbols/search.png"></span>
      <span class="slot"><img src="assets/symbols/wifi.png"></span>
      <span class="battery ${battery <= 10 ? 'low' : ''}" style="--level:${battery}%"><i></i><b></b></span>
      <span class="slot"><img src="assets/symbols/controls.png"></span>
      <span class="clock">${clock}</span></div></div>`);
}

function menuHtml(menu) {
  const [keep, lid, settings, about, quit] = T.menuItems;
  return `<div class="menu">
    <div class="item" style="padding-left:12px">${T.menuStatus[menu.status]}</div><hr>
    <div class="item ${menu.sub ? 'hl' : ''}">${keep}<span class="chev">›</span></div>
    <div class="item check">${lid}</div><hr>
    <div class="item">${settings}<span class="key">⌘,</span></div>
    <div class="item">${about}</div>
    <div class="item">${quit}<span class="key">⌘Q</span></div></div>`;
}

function dock(running = ['terminal', 'chatgpt', 'antigravity']) {
  const apps = ['finder', 'safari', 'mail', 'notes', 'calendar', 'chrome', 'vscode', 'terminal', 'antigravity', 'chatgpt', 'settings'];
  const html = apps.map((a) => `<div class="app ${running.includes(a) ? 'running' : ''}"><img src="assets/icons/${a}.png"></div>`).join('');
  return $(`<div class="dock">${html}<div class="sep"></div><div class="app"><img src="assets/icons/trash.png"></div></div>`);
}

function desktopIcons() {
  const names = ['web-app', 'api-server', 'mobile-app', 'docs-site'];
  return $(`<div class="desktop-icons">${names.map((n) => `<div class="desktop-icon"><img src="assets/icons/folder.png"><span>${n}</span></div>`).join('')}</div>`);
}

function win({ kind, x, y, w, h, inactive, fading, title, body, z = 10 }) {
  return $(`<div class="win ${kind} ${inactive ? 'inactive' : ''} ${fading ? 'fading' : ''}" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px;z-index:${z}">
    <div class="titlebar"><div class="lights"><i></i><i></i><i></i></div><div class="title">${title}</div></div><div class="body">${body}</div></div>`);
}

function terminalBody(state) {
  const t = T.term;
  const lines = [];
  lines.push(`<div class="box"><span class="tag">${t.header}</span><span class="dim">${t.path}</span></div>`);
  lines.push(`<span class="askline">&gt; ${t.ask}</span>\n`);
  lines.push(`<span class="orange">●</span> ${t.steps[0]}`);
  lines.push(`<span class="orange">●</span> ${t.steps[1]}`);
  lines.push(`<span class="orange">●</span> ${t.steps[2]}`);
  lines.push(`  <span class="ok">✓</span> ${t.result.split(' · ')[0]}   <span class="bad">✗</span> ${t.result.split(' · ')[1]}`);
  lines.push(`<span class="orange">●</span> ${t.fixing}`);
  if (state === 'interrupted') lines.push(`  <span class="dim">⎿  ${t.interrupted}</span>`);
  else if (state === 'done') lines.push(`<span class="ok">✓</span> <span class="dim">${t.done}</span>`);
  else lines.push(`\n<span class="orange">✻</span> <span class="dim">${state === 'short' ? t.workingShort : t.working}</span>`);
  return `<div class="log">${lines.join('\n')}</div><div class="inputbox"><div class="rule"></div><span class="prompt">&gt; </span><span class="cursor">▌</span><div class="rule"></div><span class="dim">${t.footer}</span></div>`;
}

function caffeinateBody() {
  return `<div class="log"><span class="prompt">$ ${T.term.caffeinate}</span>\n<span class="dim">▌</span></div>`;
}

function ideBody(done = false) {
  const c = T.ide;
  const code = [
    ['<span class="k">import</span> { Router } <span class="k">from</span> <span class="s">"express"</span>;'],
    [''],
    ['<span class="c">// One bucket per client</span>'],
    ['<span class="k">const</span> buckets = <span class="k">new</span> <span class="t">Map</span>&lt;<span class="t">string</span>, <span class="t">Bucket</span>&gt;();'],
    [''],
    ['<span class="k">export function</span> <span class="f">rateLimit</span>(limit = <span class="s">60</span>) {'],
    ['  <span class="k">return</span> (req, res, next) =&gt; {'],
    ['    <span class="k">const</span> id = req.ip ?? <span class="s">"unknown"</span>;'],
    ['    <span class="k">const</span> bucket = buckets.<span class="f">get</span>(id) ?? <span class="f">refill</span>(limit);'],
    ['    <span class="k">if</span> (bucket.tokens &lt;= <span class="s">0</span>) {'],
    ['      <span class="k">return</span> res.<span class="f">status</span>(<span class="s">429</span>).<span class="f">end</span>();'],
    ['    }'],
    ['    bucket.tokens -= <span class="s">1</span>;'],
    ['    buckets.<span class="f">set</span>(id, bucket);'],
    ['    <span class="f">next</span>();'],
    ['  };'],
    ['}'],
    [''],
    ['<span class="k">function</span> <span class="f">refill</span>(limit: <span class="t">number</span>): <span class="t">Bucket</span> {'],
    ['  <span class="k">return</span> { tokens: limit, at: Date.<span class="f">now</span>() };'],
    ['}'],
    [''],
    ['<span class="c">// Called from the router</span>'],
    ['<span class="k">export default</span> <span class="f">rateLimit</span>;'],
  ].map((l, i) => `<div><span class="n">${i + 1}</span>${l[0]}</div>`).join('');
  const steps = c.steps.map((s, i) => `<div class="step ${done || i < 2 ? 'done' : ''}"><i></i><span>${s}</span></div>`).join('') + (done ? `<p style="margin-top:14px">${c.done}</p>` : '');
  return `<div class="activity"><i></i><i></i><i></i><i></i></div>
    <div class="editor"><div class="tabs"><span>${c.tab}</span></div><div class="code">${code}</div></div>
    <div class="agent"><h4>${c.agent}</h4>${steps}<div class="input">${c.input}</div></div>
    <div class="status">${c.status}</div>`;
}

function chatBody(running = true) {
  const c = T.chat;
  return `<div class="side"><h4>${c.title} ⌄</h4><div>${c.side[0]}</div><div>${c.side[1]}</div>
      <div class="group">${c.side[2]}</div>${c.history.map((h, i) => `<div class="${i === 1 ? 'sel' : ''}">${h}</div>`).join('')}</div>
    <div class="main"><div class="bubble">${c.user}</div>
      <p>${c.lead}</p><ul>${c.bullets.map((b) => `<li><code>${b}</code></li>`).join('')}</ul>
      <div class="block">${c.block}</div>
      ${running ? `<div class="run"><i></i>${c.running}</div>` : `<div class="run">✓ ${c.done}</div>`}
      <div class="composer">${c.composer}</div></div>`;
}

const terminalWin = (o) => win({ kind: 'term', title: T.term.title, body: terminalBody(o.state), ...o });
const ideWin = (o) => win({ kind: 'ide', title: T.ide.tab + ' — web-app', body: ideBody(o.done), ...o });
const chatWin = (o) => win({ kind: 'chat', title: '', body: chatBody(o.running !== false), ...o });

// A MacBook seen from the front and above. The lid hinges over the keyboard: --beta is how far it is
// from closed (0 = shut, 100+ = open).
function laptop3d(beta) {
  const rows = [
    [1.3, ...Array(12).fill(1), 1.1, 'touch'],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.6],
    [1.6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.4],
    [1.9, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.1],
    [2.4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.6],
    [1.1, 1.1, 1.1, 1.3, 5.2, 1.3, 1.1, 1.1, 1.1],
  ];
  const keys = rows.map((r, i) => `<div class="row ${i === 0 ? 'fn' : ''}">${r.map((w) => w === 'touch' ? '<span class="key touch"></span>' : `<span class="key" style="--w:${w}"></span>`).join('')}</div>`).join('');
  return $(`<div class="laptop3d" style="--leak:${beta < 10 ? 1 : 0}"><div class="floor"></div><div class="rig">
    <div class="base"><div class="notch"></div><div class="grille l"></div><div class="grille r"></div><div class="well">${keys}</div><div class="pad"></div></div>
    <div class="hinge"></div>
    <div class="lid" style="--beta:${beta}deg"><div class="outer"><span class="logo">&#xF8FF;</span></div>
      <div class="screenface"><div class="inner"><div class="bar"></div><div class="win2"></div><div class="dock2"></div></div><div class="cam"></div><div class="glass"></div></div></div>
    <div class="glow"></div>
  </div></div>`);
}

// ---------- Scenes (one key frame each) ----------

const SCENES = {
  // 0: the hook. "ai" turns into "AI"
  0: () => ({
    wallpaper: 'blur', shade: 0.55,
    layers: [$(`<div class="big"><h1>${T.tagline[0]}<span class="ai">AI</span>${T.tagline[2]}</h1></div>`)],
  }),
  // 1: pain. The Mac is about to sleep and an hours-long run is cut off
  1: () => ({
    menubar: { app: 'terminal', icon: 'moon' }, dock: true, icons: true, shade: 0.5,
    layers: [terminalWin({ x: 300, y: 130, w: 1100, h: 700, state: 'working' }), $(`<div class="caption">${T.cap1a}</div>`)],
  }),
  // 1b: pain, the other way. The agent finishes, but caffeinate keeps the Mac awake
  '1b': () => ({
    menubar: { app: 'terminal', icon: 'moon', battery: 78, clock: 'Tue Oct 14  11:52' }, dock: true, icons: true,
    layers: [
      terminalWin({ x: 200, y: 110, w: 1000, h: 700, state: 'done', z: 10 }),
      win({ kind: 'term', x: 760, y: 330, w: 760, h: 300, inactive: true, title: T.term.caffeinateTitle, body: caffeinateBody(), z: 12 }),
      $(`<div class="caption">${T.cap1b}</div>`),
    ],
  }),
  // 1c: fast-forward, in the same desktop: the camera slides to the clock and the battery, the room darkens
  '1c': () => ({
    menubar: { app: 'terminal', icon: 'moon', battery: 31, clock: 'Wed Oct 15  3:07' }, dock: true, icons: true, shade: 0.55,
    camera: { x: 1700, y: 17, scale: 2.6 },
    layers: [
      terminalWin({ x: 200, y: 110, w: 1000, h: 700, state: 'done', inactive: true, z: 10 }),
      $(`<div class="caption">${T.cap1c}</div>`),
    ],
  }),
  // 1d: the battery is empty: the screen goes dark
  '1d': () => ({
    wallpaper: 'black',
    layers: [$(`<div class="caption">${T.cap1d}</div>`)],
  }),
  // 2: the solution. Zoom on the menu bar; the icon sparkles and the menu says an agent is working
  2: () => ({
    menubar: { app: 'terminal', icon: 'sparkles', active: true, menu: { status: 'one' } }, dock: true, icons: true,
    camera: { focus: 'status', scale: 2.5, dy: 150 },
    layers: [terminalWin({ x: 300, y: 130, w: 1100, h: 700, state: 'short' })],
  }),
  // 3: three agents at once, three kinds of app
  3: () => ({
    menubar: { app: 'terminal', icon: 'sparkles', active: false }, dock: true, icons: true,
    layers: [
      ideWin({ x: 70, y: 84, w: 1130, h: 680, inactive: true, z: 10 }),
      chatWin({ x: 520, y: 130, w: 1050, h: 620, inactive: true, z: 11 }),
      terminalWin({ x: 1000, y: 260, w: 860, h: 560, state: 'short', z: 12 }),
      $(`<div class="caption">${T.cap3}</div>`),
    ],
  }),
  // 3b: the other two agents finish and their windows go away; only one is still working
  '3b': () => ({
    menubar: { app: 'terminal', icon: 'sparkles', active: false }, dock: true, icons: true,
    layers: [
      ideWin({ x: 70, y: 84, w: 1130, h: 680, inactive: true, fading: true, done: true, z: 10 }),
      chatWin({ x: 520, y: 130, w: 1050, h: 620, inactive: true, fading: true, running: false, z: 11 }),
      terminalWin({ x: 1000, y: 260, w: 860, h: 560, state: 'short', z: 12 }),
    ],
  }),
  // 4: the one left is interrupted halfway; the icon is back to the moon
  4: () => ({
    menubar: { app: 'terminal', icon: 'moon', active: false }, dock: true, icons: true,
    layers: [terminalWin({ x: 300, y: 130, w: 1100, h: 700, state: 'interrupted' }), $(`<div class="caption">${T.cap4}</div>`),
      $(`<div class="ring" style="left:1563px;top:3px;width:40px;height:28px"></div>`)],
  }),
  // 5: lid closed, still running
  5: () => ({
    wallpaper: 'blur', shade: 0.5,
    layers: [laptop3d(58), $(`<div class="caption" style="bottom:130px">${T.cap5}</div>`)],
  }),
  // 5b: it stops by itself when...
  '5b': () => ({
    wallpaper: 'blur', shade: 0.5,
    layers: [laptop3d(0), $(`<div class="caption" style="bottom:110px">${T.cap5b}<div class="pills">${T.pills.map((p) => `<span>${p}</span>`).join('')}</div></div>`)],
  }),
  // 6: peace of mind. The Activity screen, "stored only on your Mac"
  6: () => ({
    wallpaper: 'blur', shade: 0.45,
    layers: [$(`<img class="shot" src="../../docs/media/shot-settings-activity-dark-${lang}.webp">`), $(`<div class="caption" style="bottom:46px">${T.cap6}</div>`)],
  }),
  // 7: the end. "AI" has gone back to lowercase: the agents are done
  7: () => ({
    wallpaper: 'blur', shade: 0.72,
    layers: [$(`<div class="finale"><img class="moon" src="assets/symbols/moon.png"><h1>${T.finale}</h1>
      <div class="dl"><img src="assets/icons/remain.png">${T.download}</div></div>`)],
  }),
};

// ---------- Render ----------

function render(id) {
  const lid = /^lid-(\d+)$/.exec(id);
  const spec = lid ? { wallpaper: 'blur', shade: 0.5, layers: [laptop3d(Number(lid[1]))] } : SCENES[id]();
  const cam = document.getElementById('camera');
  document.querySelectorAll('#stage > .caption, #stage > .big, #stage > .finale').forEach((e) => e.remove());
  cam.innerHTML = '';
  const wp = $(`<div class="wallpaper"></div>`);
  if (spec.wallpaper === 'blur') wp.style.filter = 'blur(26px) saturate(1.1)';
  if (spec.wallpaper === 'black') wp.style.background = '#000';
  cam.appendChild(wp);
  if (spec.icons) cam.appendChild(desktopIcons());
  (spec.layers || []).forEach((l) => cam.appendChild(l));
  if (spec.dock) cam.appendChild(dock());
  if (spec.menubar) cam.appendChild(menubar(spec.menubar));
  if (spec.shade) { const s = $(`<div class="shade"></div>`); s.style.opacity = spec.shade; cam.appendChild(s); }
  // The shade sits under captions, big text and menus.
  // Captions and titles stay put when the camera zooms: they live above the camera, not inside it.
  cam.querySelectorAll('.caption, .big, .finale').forEach((e) => { e.style.zIndex = 90; document.getElementById('stage').appendChild(e); });
  if (spec.camera) {
    const { scale, dy = 0 } = spec.camera;
    let { x, y } = spec.camera;
    if (spec.camera.focus === 'status') {
      const r = document.getElementById('status').getBoundingClientRect();
      x = r.left + r.width / 2 - 120; y = r.top + r.height / 2 + dy;
    }
    // Keep the picture inside the screen: never show the black behind the desktop.
    const tx = Math.min(0, Math.max(1920 - 1920 * scale, 960 - x * scale));
    const ty = Math.min(0, Math.max(1080 - 1080 * scale, 540 - y * scale));
    cam.style.transform = `translate(${tx}px, ${ty}px) scale(${scale})`;
  } else cam.style.transform = 'none';
  document.body.dataset.ready = '1';
}

render(params.get('scene') || '1');
