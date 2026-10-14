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
    cap3: 'Any agent. All at once.',
    cap4: 'Stopped halfway? It notices.',
    cap5: 'Close the lid. It keeps going.',
    cap5b: 'And it stops by itself when…',
    pills: ['It gets too hot', 'The battery runs low', 'Your time limit runs out'],
    cap6: 'Nothing leaves your Mac.',
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
    notifStop: { title: 'An agent stopped unexpectedly', body: 'web-app · Keep-awake has ended.' },
    // Window contents (invented)
    term: {
      title: 'web-app — claude — 100×30',
      header: 'Claude Code',
      path: '~/Projects/web-app',
      ask: 'Add rate limiting to the API and make the tests pass',
      log: [
        '● Reading src/api/middleware.ts',
        '● Reading src/api/router.ts',
        '● Reading src/config/limits.ts',
        '● Searching for "rateLimit" in src/',
        '● Editing src/api/rateLimit.ts  (+42 −3)',
        '● Editing src/api/router.ts  (+6 −1)',
        '● Editing src/config/limits.ts  (+4 −0)',
        '● Running npm test',
        '  ✓ 46 passed   ✗ 2 failed',
        '● Reading tests/rateLimit.test.ts',
        '● Editing tests/rateLimit.test.ts  (+9 −4)',
        '● Running npm test',
        '  ✓ 48 passed',
        '● Checking types with tsc --noEmit',
        '  ✓ No errors',
        '● Running npm run lint',
        '  ✓ No issues',
        '● Editing README.md  (+12 −0)',
        '● Running npm test -- --coverage',
        '  ✓ 48 passed · 94% coverage',
        '● Reading docs/api.md',
        '● Editing docs/api.md  (+18 −2)',
        '● Running npm run build',
        '  ✓ Build succeeded',
      ],
      // The same job, much later: what the terminal shows when the run is over.
      logLate: [
        '● Searching for "x-forwarded-for" in src/',
        '● Editing src/api/clientId.ts  (+11 −2)',
        '● Editing tests/clientId.test.ts  (+22 −0)',
        '● Running npm test',
        '  ✓ 51 passed',
        '● Running npm run lint',
        '  ✓ No issues',
        '● Editing docs/rate-limiting.md  (+31 −0)',
        '● Reading CHANGELOG.md',
        '● Editing CHANGELOG.md  (+5 −0)',
        '● Running npm test -- --coverage',
        '  ✓ 52 passed · 96% coverage',
        '● Running git diff --stat',
        '  8 files changed, 214 insertions(+), 19 deletions(-)',
        '● Creating commit "Add per-client rate limiting"',
        '  ✓ Committed 3f9c2e1',
        '',
        'Done. Per-client rate limiting is in place:',
        '  · 60 requests per minute per client, set in src/config/limits.ts',
        '  · Over the limit, the API answers 429 with a Retry-After header',
        '  · 8 new tests cover it, and the full suite passes',
        '',
      ],
      // Other jobs for the trouble scene, so no two parts of the video show the same prompt or log.
      jobs: {
        sleep: {
          ask: 'Migrate the database from MySQL to Postgres 16', cut: 13, error: 'Error: request timed out',
          log: [
            '● Reading db/schema.sql', '● Reading src/db/connection.ts', '● Searching for "mysql" in src/',
            '● Editing package.json  (+2 −1)', '● Running npm install', '  ✓ 3 packages changed',
            '● Editing src/db/connection.ts  (+24 −18)', '● Creating db/migrations/001_init.sql  (+212 −0)',
            '● Running npm run migrate', '  ✓ 14 tables migrated', '● Editing src/models/user.ts  (+9 −7)',
            '● Editing src/models/order.ts  (+14 −11)', '● Running npm test', '  ✓ 61 passed  ✗ 3 failed',
            '● Editing src/models/order.ts  (+6 −4)',
          ],
        },
        night: {
          ask: 'Write the API reference for the public endpoints', cut: 99, error: '',
          log: [
            '● Reading src/api/router.ts', '● Reading src/api/schemas.ts', '● Searching for "@route" in src/',
            '● Creating docs/api/index.md  (+48 −0)', '● Creating docs/api/users.md  (+96 −0)',
            '● Creating docs/api/orders.md  (+128 −0)', '● Running npm run docs:check', '  ✓ 0 broken links',
            '● Reading docs/api/orders.md', '● Editing docs/api/orders.md  (+14 −3)',
            '● Creating docs/api/errors.md  (+57 −0)', '● Running npm run docs:build', '  ✓ Built 18 pages',
          ],
          logLate: [
            '● Editing docs/api/users.md  (+22 −4)', '● Creating docs/api/webhooks.md  (+74 −0)',
            '● Running npm run docs:check', '  ✓ 0 broken links', '● Running npm run docs:build', '  ✓ Built 21 pages',
            '', 'Done. The public API is documented:', '  · 14 endpoints across users, orders and webhooks',
            '  · Every page has a request and a response example', '  · The docs build passes with no broken links', '',
          ],
        },
      },
      working: 'Working… (2h 41m · esc to interrupt)',
      workingShort: 'Working… (3m 12s · esc to interrupt)',
      error: 'Error: connection lost',
      done: 'Worked for 14m 32s',
      footer: '? for shortcuts · ← for agents',
      caffeinate: 'caffeinate -i',
      caffeinateTitle: 'Terminal — caffeinate',
    },
    ide: { tab: 'rateLimit.ts', agent: 'Agent', done: 'Finished. 4 files changed.', steps: ['Read middleware.ts', 'Add a token bucket per client', 'Wire it into the router', 'Run the test suite'],
      sub: [['src/api/middleware.ts · 84 lines'], ['Edited src/api/rateLimit.ts  +42 −3', 'Created src/api/bucket.ts  +28'], ['Edited src/api/router.ts  +6 −1'], ['$ npm test', '48 passed · 0 failed']], input: 'Ask anything…', status: 'Main · 0 problems · TypeScript' },
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

function menubar({ app, icon, active, menu, battery = 82, lowBattery = false, clock = T.clock }) {
  const names = T.menus[app];
  const left = names.map((n, i) => `<span class="${i === 0 ? 'appname' : ''}">${n}</span>`).join('');
  const status = icon ? `<span class="slot status ${active ? 'active' : ''}" id="status"><img src="assets/symbols/${icon}.png">${menu ? menuHtml(menu) : ''}</span>` : '';
  return $(`<div class="menubar"><div class="left"><span class="apple">&#xF8FF;</span>${left}</div>
    <div class="right">${status}
      <span class="slot"><img src="assets/symbols/search.png"></span>
      <span class="slot"><img src="assets/symbols/wifi.png"></span>
      <span class="battery ${battery <= 10 || lowBattery ? 'low' : ''}" style="--level:${battery}%"><i></i><b></b></span>
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

// A terminal shows its log the way a terminal does: lines pop in whole, the prompt is typed key by key,
// and the spinner glyph and the clock tick. `shown` is how many entries are visible (omit for all);
// a fractional value types the prompt line out. `tick` is seconds, for the spinner and the cursor.
function terminalBody(state, shown = 999, tick = 0, job = null) {
  const t = T.term;
  const j = { ask: t.ask, log: t.log, logLate: t.logLate, error: t.error, cut: 11, ...(job ? T.term.jobs[job] : {}) };
  const glyphs = ['✻', '✽', '✢', '✳'];
  const spin = glyphs[Math.floor(tick * 4) % glyphs.length];
  const sec = Math.floor(tick);
  const elapsed = sec < 60 ? `${sec}s` : `${Math.floor(sec / 60)}m ${String(sec % 60).padStart(2, '0')}s`;
  const working = `Working… (${elapsed} · esc to interrupt)`;
  const ask = (n) => `<span class="askline">&gt; ${j.ask.slice(0, n)}${n < j.ask.length ? '▌' : ''}</span>\n`;
  const style = (line) => line
    .replace('●', '<span class="orange">●</span>')
    .replace('✓', '<span class="ok">✓</span>').replace('✗', '<span class="bad">✗</span>');
  // An interrupted run stops partway through the log; a finished one continues far beyond what the
  // first part showed (the terminal scrolls, so only its newest lines are in view).
  const log = (state === 'error' ? j.log.slice(0, j.cut) : j.log).map(style);
  const entries = [`<div class="box"><span class="tag">${t.header}</span><span class="dim">${t.path}</span></div>`, ask(j.ask.length), ...log];
  if (state === 'done') entries.push(...(j.logLate || []).map(style), `<span class="ok">✓</span> <span class="dim">${t.done}</span>`);
  const count = Math.min(Math.ceil(shown), entries.length);
  if (shown % 1 !== 0 && count === 2) entries[1] = ask(Math.round(j.ask.length * (shown % 1)));
  const visible = entries.slice(0, count);
  if (state === 'error' && count >= entries.length) visible.push(`\n<span class="bad">⎿  ${j.error}</span>`);
  if (state === 'short' && shown >= 2) visible.push(`\n<span class="orange">${spin}</span> <span class="dim">${working}</span>`);
  const cursorOn = Math.floor(tick * 2) % 2 === 0;
  return `<div class="log">${visible.join('\n')}</div><div class="inputbox"><div class="rule"></div><span class="prompt">&gt; </span><span class="cursor" style="opacity:${cursorOn ? 1 : 0}">▌</span><div class="rule"></div><span class="dim">${t.footer}</span></div>`;
}

function caffeinateBody() {
  return `<div class="log"><span class="prompt">$ ${T.term.caffeinate}</span>\n<span class="dim">▌</span></div>`;
}

function ideBody(done = false, shown = 999) {
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
  // The agent panel streams its work: a step, then what it did, one entry at a time (`shown` entries so far).
  const flat = [];
  c.steps.forEach((st, i) => { flat.push({ step: st, i }); (c.sub[i] || []).forEach((l) => flat.push({ sub: l, i })); });
  const n = done ? flat.length : Math.min(Math.ceil(shown), flat.length);
  const cur = n ? flat[n - 1].i : -1;
  const steps = flat.slice(0, n).map((e) => e.step
    ? `<div class="step ${done || e.i < cur ? 'done' : 'now'}"><i></i><span>${e.step}</span></div>`
    : `<div class="sub">${e.sub}</div>`).join('') + (done ? `<p style="margin-top:14px">${c.done}</p>` : '');
  return `<div class="activity"><i></i><i></i><i></i><i></i></div>
    <div class="agent"><h4>${c.agent}</h4>${steps}<div class="input">${c.input}</div></div>
    <div class="editor"><div class="tabs"><span>${c.tab}</span></div><div class="code">${code}</div></div>
    <div class="status">${c.status}</div>`;
}

function chatBody(running = true, tick = 0) {
  const c = T.chat;
  return `<div class="side"><h4>${c.title} ⌄</h4><div>${c.side[0]}</div><div>${c.side[1]}</div>
      <div class="group">${c.side[2]}</div>${c.history.map((h, i) => `<div class="${i === 1 ? 'sel' : ''}">${h}</div>`).join('')}</div>
    <div class="main"><div class="bubble">${c.user}</div>
      <p>${c.lead}</p><ul>${c.bullets.map((b) => `<li><code>${b}</code></li>`).join('')}</ul>
      <div class="block">${c.block}</div>
      ${running ? `<div class="run"><i style="transform:rotate(${(tick * 360).toFixed(0)}deg)"></i>${c.running}</div>` : `<div class="run">✓ ${c.done}</div>`}
      <div class="composer">${c.composer}</div></div>`;
}

const terminalWin = (o) => win({ kind: 'term', title: T.term.title, body: terminalBody(o.state, o.shown, o.tick, o.job), ...o });
const ideWin = (o) => win({ kind: 'ide', title: T.ide.tab + ' — web-app', body: ideBody(o.done, o.shown), ...o });
const chatWin = (o) => win({ kind: 'chat', title: '', body: chatBody(o.running !== false, o.tick), ...o });

// A MacBook seen from the front and above. The lid hinges over the keyboard: --beta is how far it is
// from closed (0 = shut, 100+ = open).
function laptop3d(beta, { leakMul = 1, screen = 1 } = {}) {
  const rows = [
    [1.3, ...Array(12).fill(1), 1.1, 'touch'],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.6],
    [1.6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.4],
    [1.9, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.1],
    [2.4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.6],
    [1.1, 1.1, 1.1, 1.3, 5.2, 1.3, 1.1, 1.1, 1.1],
  ];
  const keys = rows.map((r, i) => `<div class="row ${i === 0 ? 'fn' : ''}">${r.map((w) => w === 'touch' ? '<span class="key touch"></span>' : `<span class="key" style="--w:${w}"></span>`).join('')}</div>`).join('');
  const slab = (cls, n, from, to) => Array.from({ length: n }, (_, i) => {
    const t = i / (n - 1), c = Math.round(from + (to - from) * t);
    return `<div class="${cls}" style="transform:translateZ(${cls === 'bslab' ? -(i + 1) : (i + 1)}px);background:rgb(${c},${c + 2},${c + 8})"></div>`;
  }).join('');
  // Everything follows from the lid angle: the screen light only leaks once the lid is nearly shut,
  // and the whole machine is drawn a little smaller when it is wide open so it fits the frame.
  const clamp = (v) => Math.max(0, Math.min(1, v));
  const leak = clamp((14 - beta) / 14) * leakMul, scale = 1 - 0.28 * clamp((beta - 60) / 50);
  return $(`<div class="laptop3d" style="--leak:${leak.toFixed(3)};transform:scale(${scale.toFixed(3)});transform-origin:50% 62%;"><div class="floor"></div><div class="rig">${slab('bslab', 16, 60, 24)}
    <div class="base"><div class="notch"></div><div class="grille l"></div><div class="grille r"></div><div class="well">${keys}</div><div class="pad"></div></div>
    <div class="hinge" style="opacity:${clamp((beta - 12) / 16).toFixed(2)}"></div>
    <div class="lid" style="--beta:${beta}deg">${slab('lslab', 8, 48, 66)}<div class="outer"><span class="logo">&#xF8FF;</span></div>
      <div class="screenface" style="--on:${screen}"><div class="inner" style="opacity:${screen}"><div class="bar"></div><div class="win2"></div><div class="dock2"></div></div><div class="cam"></div><div class="glass"></div></div></div>
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
    layers: [terminalWin({ x: 300, y: 130, w: 1100, h: 700, state: 'error' }), $(`<div class="caption">${T.cap4}</div>`),
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
  scrollTerminals();
  document.body.dataset.ready = '1';
}

// A terminal follows its newest line: when the log is taller than the window, the oldest lines scroll off the top.
function scrollTerminals() { document.querySelectorAll('.term .log').forEach((el) => { el.scrollTop = el.scrollHeight; }); }
Object.assign(window, { scrollTerminals, $, T, menubar, menuHtml, dock, desktopIcons, win, terminalWin, ideWin, chatWin, laptop3d, caffeinateBody });
if (params.get('mode') !== 'video') render(params.get('scene') || '1');
