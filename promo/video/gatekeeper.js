// Scene "gk": how to open an app that Apple has not signed, drawn the way macOS shows it (Safari, Finder, System Settings,
// the warning, the confirmation, Touch ID) with a pointer that moves smoothly. The wording of the system screens is the
// real macOS wording in each language; the account name and the Dock are made up.
//
//   node promo/video/record.mjs --lang ja gk        -> promo/video/out/clip-gk-ja.mp4

const GKT = {
  en: {
    clock: 'Fri Oct 17  3:17 PM',
    menus: { safari: ['Safari', 'File', 'Edit', 'View', 'History', 'Bookmarks', 'Window', 'Help'], settings: ['System Settings', 'Edit', 'View', 'Window', 'Help'] },
    site: { lead: 'Your Mac stays awake while AI agents work, and sleeps as usual when they are done.', download: 'Download for macOS', intro: 'Watch the intro' },
    finder: { title: 'Downloads', side: [['Favorites'], 'Recents', 'Applications', 'Desktop', 'Documents', 'Downloads', ['Locations'], 'iCloud Drive', 'Macintosh HD'], select: 5, cols: ['Name', 'Size', 'Kind', 'Date Added'], row: ['remAIn', '6.5 MB', 'Application', 'Today at 3:17 PM'] },
    alert1: { title: '“remAIn” Not Opened', body: 'Apple could not verify “remAIn” is free of malware that may harm your Mac or compromise your privacy.', buttons: ['Move to Trash', 'Done'] },
    settings: {
      search: 'Search', name: 'Taro Yamada', account: 'Apple Account',
      groups: [['Wi-Fi', 'Bluetooth', 'Network', 'VPN', 'Battery'], ['General', 'Accessibility', 'Siri', 'Spotlight', 'Displays', 'Desktop & Dock', 'Menu Bar', 'Appearance', 'Wallpaper'], ['Notifications', 'Sound', 'Focus', 'Screen Time'], ['Lock Screen', 'Privacy & Security', 'Touch ID & Password', 'Users & Groups'], ['Game Center', 'iCloud', 'Internet Accounts', 'Wallet & Apple Pay']],
      generalTitle: 'General', generalText: 'Manage your overall setup and preferences for Mac, such as software updates, device language, AirDrop and more.',
      privacy: 'Privacy & Security',
      rows: [['Location Services', 'Off'], ['Calendars', 'None'], ['Files & Folders', '1 app'], ['Full Disk Access', '1 app'], ['Photos', 'None'], ['Microphone', 'None'], ['Screen & System Audio Recording', '5'], ['Input Monitoring', '2'], ['Analytics & Improvements', ''], ['Apple Advertising', ''], ['Apple Intelligence Report', 'On']],
      security: 'Security', allow: ['Allow applications from', 'App Store & Known Developers'],
      blocked: '“remAIn” was blocked to protect your Mac.', blockedSub: 'Apple could not verify “remAIn” is free of malware that may harm your Mac or compromise your privacy.', openAnyway: 'Open Anyway',
      after: [['FileVault', 'On'], ['Lockdown Mode', 'Off']],
    },
    alert2: { title: 'Open “remAIn”?', body: 'Apple is not able to verify that “remAIn” is free from malware that may harm your Mac or compromise your privacy. Unless you trust the source of this app, you shouldn’t open it.', buttons: ['Move to Trash', 'Open Anyway', 'Done'] },
    touch: { body: 'You are about to open an app that may harm your Mac or compromise your privacy. To continue in Privacy & Security, use Touch ID or enter your administrator name and password.', buttons: ['Use Password…', 'Cancel'] },
    steps: ['Download', 'Open it', 'If a warning appears, click “Done”', 'System Settings → Privacy & Security', 'Click “Open Anyway”', 'Confirm with Touch ID or your password', 'It opens'],
  },
  ja: {
    clock: '10月17日(金)  15:17',
    menus: { safari: ['Safari', 'ファイル', '編集', '表示', '履歴', 'ブックマーク', 'ウインドウ', 'ヘルプ'], settings: ['システム設定', '編集', '表示', 'ウインドウ', 'ヘルプ'] },
    site: { lead: 'AIエージェントが働いているあいだだけ、Macを起こしておきます。終われば、いつもどおりスリープします。', download: 'macOS版をダウンロード', intro: '紹介動画を見る' },
    finder: { title: 'ダウンロード', side: [['よく使う項目'], '最近の項目', 'アプリケーション', 'デスクトップ', '書類', 'ダウンロード', ['場所'], 'iCloud Drive', 'Macintosh HD'], select: 5, cols: ['名前', 'サイズ', '種類', '追加日'], row: ['remAIn', '6.5 MB', 'アプリケーション', '今日 15:17'] },
    alert1: { title: '“remAIn”は開いていません', body: 'Appleは、“remAIn”にMacに損害を与えたり、プライバシーを侵害する可能性のあるマルウェアが含まれていないことを検証できませんでした。', buttons: ['ゴミ箱に入れる', '完了'] },
    settings: {
      search: '検索', name: '山田 太郎', account: 'Apple Account',
      groups: [['Wi-Fi', 'Bluetooth', 'ネットワーク', 'VPN', 'バッテリー'], ['一般', 'アクセシビリティ', 'Siri', 'Spotlight', 'ディスプレイ', 'デスクトップとDock', 'メニューバー', '外観', '壁紙'], ['通知', 'サウンド', '集中モード', 'スクリーンタイム'], ['ロック画面', 'プライバシーとセキュリティ', 'Touch IDとパスワード', 'ユーザとグループ'], ['Game Center', 'iCloud', 'インターネットアカウント', 'ウォレットとApple Pay']],
      generalTitle: '一般', generalText: 'ソフトウェアアップデート、デバイスの言語、AirDropなど、Macの全体的な設定や自分の好みの設定を管理します。',
      privacy: 'プライバシーとセキュリティ',
      rows: [['位置情報サービス', 'オフ'], ['カレンダー', 'なし'], ['ファイルとフォルダ', '1個のアプリ'], ['フルディスクアクセス', '1個のアプリ'], ['写真', 'なし'], ['マイク', 'なし'], ['画面収録とシステムオーディオ録音', '5'], ['入力監視', '2'], ['解析と改善', ''], ['Appleの広告', ''], ['Apple Intelligenceレポート', 'オン']],
      security: 'セキュリティ', allow: ['アプリケーションの実行許可', 'App Storeと既知のデベロッパ'],
      blocked: 'お使いのMacを保護するために“remAIn”がブロックされました。', blockedSub: 'Appleは、“remAIn”にMacに損害を与えたり、プライバシーを侵害する可能性のあるマルウェアが含まれていないことを検証できませんでした。', openAnyway: 'このまま開く',
      after: [['FileVault', 'オン'], ['ロックダウンモード', 'オフ']],
    },
    alert2: { title: '“remAIn”を開きますか?', body: 'Appleは、このアプリにMacに損害を与えたり、プライバシーを侵害する可能性のあるマルウェアが含まれていないことを検証できません。信頼できる提供元からのものであることが確認できない限り、このアプリを開いていないでください。', buttons: ['ゴミ箱に入れる', 'このまま開く', '完了'] },
    touch: { body: 'Macに損害を与えたり、プライバシーを侵害する可能性のあるアプリを開こうとしています。プライバシーとセキュリティで続けるには、Touch IDを使用するか、管理者の名前とパスワードを入力してください。', buttons: ['パスワードを使用…', 'キャンセル'] },
    steps: ['ダウンロードする', '開く', '警告が出たら「完了」を押す', 'システム設定 → プライバシーとセキュリティ', '「このまま開く」を押す', 'Touch IDかパスワードで認証', '開けました'],
  },
};
const GK = GKT[lang] || GKT.en;
Object.assign(T.menus, GK.menus);

// ---- Geometry (everything the pointer needs to find)
const G = {
  safari: { x: 300, y: 130, w: 1320, h: 750 },
  finder: { x: 420, y: 200, w: 1080, h: 560 },
  settings: { x: 400, y: 120, w: 1120, h: 830 },
  a1: { x: 750, y: 240, w: 420, h: 350 },
  a2: { x: 740, y: 190, w: 440, h: 500 },
  touch: { x: 790, y: 240, w: 340, h: 400 },
  dockIcon: 64, dockStep: 74,
};
const DOCK_APPS = ['finder', 'safari', 'mail', 'messages', 'maps', 'photos', 'facetime', 'calendar', 'contacts', 'notes', 'music', 'appstore', 'settings'];
G.dockX0 = (1920 - (14 + DOCK_APPS.length * G.dockStep + 16 + 64 + 14)) / 2;
const dockCenter = (name) => ({ x: G.dockX0 + 14 + DOCK_APPS.indexOf(name) * G.dockStep + 32, y: 1024 });
// the pointer's targets
const SIDEBAR_SCROLL = 360, PANE_SCROLL = 480;
function sidebarLayout() { // y of every row inside the sidebar's scroll area
  const rows = []; let y = 36 + 14 + 60 + 8;
  GK.settings.groups.forEach((g, gi) => { if (gi) y += 14; g.forEach((name) => { rows.push({ name, y }); y += 38; }); });
  return rows;
}
const privacyRow = () => sidebarLayout().find((r) => r.name === GK.settings.privacy);
const TARGET = {
  download: { x: G.safari.x + 402 + 125, y: G.safari.y + 56 + 410 + 25 },
  finderRow: { x: G.finder.x + 220 + 120, y: G.finder.y + 92 + 16 },
  a1Done: { x: G.a1.x + G.a1.w / 2, y: G.a1.y + G.a1.h - 24 - 19 },
  dockSettings: dockCenter('settings'),
  privacyRow: () => ({ x: G.settings.x + 12 + 130, y: G.settings.y + 64 + privacyRow().y - SIDEBAR_SCROLL + 19 }),
  openAnyway: { x: G.settings.x + 290 + 24 + (782 - 24 - 132) + 66, y: G.settings.y + 56 + (824 - PANE_SCROLL) + 24 + 17 },
  a2Open: { x: G.a2.x + G.a2.w / 2, y: G.a2.y + G.a2.h - 24 - 38 - 48 + 19 },
};

// ---- Pieces
const el = (html) => $(html.trim());
const px = (o) => `left:${o.x}px;top:${o.y}px;width:${o.w}px;height:${o.h}px`;
const lights = '<div class="lights"><i></i><i></i><i></i></div>';

function gkSafari(off, dlProgress) {
  const g = G.safari, s = GK.site;
  const dl = dlProgress > 0 ? `<div class="dl" style="opacity:${Math.min(1, dlProgress * 6).toFixed(2)}"><svg width="30" height="30" viewBox="0 0 30 30"><circle cx="15" cy="15" r="11" fill="none" stroke="rgba(255,255,255,.2)" stroke-width="3"/><circle cx="15" cy="15" r="11" fill="none" stroke="#7fb2ff" stroke-width="3" stroke-linecap="round" stroke-dasharray="${(69 * Math.min(1, dlProgress)).toFixed(1)} 100" transform="rotate(-90 15 15)"/><path d="M15 9v9m-4-3 4 4 4-4" stroke="#7fb2ff" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round" opacity="${dlProgress >= 1 ? 1 : 0}"/></svg></div>` : '';
  return el(`<div class="gk gk-safari ${off ? 'off' : ''}" style="${px(g)}">${lights}<div class="bar"><div class="url">haruhito767676.github.io</div>${dl}</div>
    <div class="page"><div class="nav"><img src="assets/icons/remain.png">remAIn</div><img class="gkicon" src="assets/icons/remain.png">
      <h1>rem<b>AI</b>n</h1><p>${s.lead}</p><div class="btn a">${s.download}</div><div class="btn b">${s.intro}</div></div></div>`);
}

function gkFinder(off, selected) {
  const g = G.finder, f = GK.finder;
  const side = f.side.map((x, i) => Array.isArray(x) ? `<h6>${x[0]}</h6>` : `<div class="${i === f.select ? 'sel' : ''}"><i></i>${x}</div>`).join('');
  return el(`<div class="gk gk-finder ${off ? 'off' : ''}" style="${px(g)}">${lights}<div class="side">${side}</div>
    <div class="main"><div class="tb">${f.title}</div>
      <div class="head"><span class="c1">${f.cols[0]}</span><span class="c2">${f.cols[1]}</span><span class="c3">${f.cols[2]}</span><span class="c4">${f.cols[3]}</span></div>
      <div class="row ${selected ? 'sel' : ''}"><span class="c1"><img src="assets/icons/remain-small.png">${f.row[0]}</span><span class="c2">${f.row[1]}</span><span class="c3">${f.row[2]}</span><span class="c4">${f.row[3]}</span></div>
      <div class="stripes"></div></div></div>`);
}

const ICON_COLORS = ['#3b82f6', '#2563eb', '#16a34a', '#0ea5e9', '#22c55e', '#8e8e93', '#6366f1', '#ec4899', '#f97316', '#3b82f6', '#a855f7', '#0ea5e9', '#14b8a6', '#8b5cf6', '#ef4444', '#f59e0b', '#06b6d4', '#64748b', '#84cc16', '#d946ef', '#10b981', '#3b82f6', '#f43f5e', '#eab308', '#0891b2', '#7c3aed', '#fb923c', '#4ade80'];
function gkSettings(t) {
  const g = G.settings, s = GK.settings;
  const onPrivacy = t >= 13.3;
  // sidebar
  let n = 0;
  const sideScroll = ease(prog(t, 11.0, 12.5)) * SIDEBAR_SCROLL;
  const items = s.groups.map((grp, gi) => (gi ? '<div class="gap"></div>' : '<div style="height:8px"></div>') + grp.map((name) => {
    const sel = onPrivacy ? name === s.privacy : name === s.groups[1][0];
    return `<div class="item ${sel ? 'sel' : ''}"><i class="ic" style="background:${ICON_COLORS[n++ % ICON_COLORS.length]}"></i>${name}</div>`;
  }).join('')).join('');
  // panes
  const scroll = ease(prog(t, 13.9, 15.7)) * PANE_SCROLL;
  const rowsHtml = s.rows.map((r, i) => `<div class="r" style="top:${i * 50}px"><span class="l"><i class="ic" style="background:${ICON_COLORS[(i + 6) % ICON_COLORS.length]}"></i>${r[0]}</span><em>${r[1]}</em></div>`).join('');
  const privacy = `<div class="pane" style="transform:translateY(${-scroll.toFixed(1)}px)">
      <div class="card" style="top:24px;height:92px"><div class="r" style="top:12px;height:68px;border:0;font-size:13.5px;color:rgba(255,255,255,.6)"><span class="l"><i class="ic" style="background:#3b82f6"></i>${GK.settings.privacy}</span></div></div>
      <div class="card" style="top:136px;height:${s.rows.length * 50}px">${rowsHtml}</div>
      <h5 style="top:${136 + s.rows.length * 50 + 24}px">${s.security}</h5>
      <div class="card" style="top:752px;height:56px"><div class="r" style="top:0;height:56px"><span>${s.allow[0]}</span><em>${s.allow[1]}</em></div></div>
      <div class="card block" style="top:824px;height:124px"><div class="msg">${s.blocked}</div><div class="sub">${s.blockedSub}</div><div class="btn2" style="left:${782 - 24 - 132}px;top:24px;width:132px">${s.openAnyway}</div></div>
      <div class="card" style="top:968px;height:100px">${s.after.map((r, i) => `<div class="r" style="top:${i * 50}px"><span>${r[0]}</span><em>${r[1]}</em></div>`).join('')}</div></div>`;
  const general = `<div class="general"><div class="gbig"><svg viewBox="0 0 84 84" width="84" height="84"><g fill="none" stroke="#f2f2f5" stroke-width="5" stroke-linecap="round"><circle cx="42" cy="42" r="12"/><circle cx="42" cy="42" r="26" stroke-dasharray="7 9.2"/></g></svg></div><b>${s.generalTitle}</b><p>${s.generalText}</p></div>`;
  const fade = ease(prog(t, 13.3, 13.7));
  return el(`<div class="gk gk-settings" style="${px(g)}">${lights}
    <div class="side"><div class="scroll"><div style="transform:translateY(${-sideScroll.toFixed(1)}px)"><div class="search">${s.search}</div>
      <div class="profile"><div class="av">${s.name.slice(0, 1)}</div><div><b>${s.name}</b><span>${s.account}</span></div></div>${items}</div></div></div>
    <div class="content"><div class="topbar"><span class="nv">‹ ›</span>${onPrivacy ? s.privacy : s.generalTitle}</div>
      <div style="position:absolute;inset:0;opacity:${(1 - fade).toFixed(3)}">${general}</div>
      <div style="position:absolute;inset:0;opacity:${fade.toFixed(3)}">${privacy}</div></div></div>`);
}

const GATE_ICON = `<svg class="ico" viewBox="0 0 74 74"><rect x="3" y="3" width="68" height="68" rx="16" fill="#5d5d63"/><circle cx="37" cy="37" r="20" fill="none" stroke="#d1d1d6" stroke-width="5"/><circle cx="37" cy="37" r="8" fill="#d1d1d6"/><path d="M52 34 L66 60 H38 Z" fill="#ffcc00" stroke="#b38f00" stroke-width="1.5" stroke-linejoin="round"/><path d="M52 44v7" stroke="#222" stroke-width="3" stroke-linecap="round"/><circle cx="52" cy="55" r="1.8" fill="#222"/></svg>`;
function gkAlert(box, title, body, buttons, primary, bodyTop, bodyHeight) {
  const bh = 38, gap = 10;
  const btns = buttons.map((label, i) => {
    const fromBottom = buttons.length - 1 - i;
    const top = box.h - 24 - bh - fromBottom * (bh + gap);
    return `<div class="b ${i === primary ? 'p' : ''}" style="top:${top}px">${label}</div>`;
  }).join('');
  return el(`<div class="gk gk-alert" style="${px(box)}">${GATE_ICON}<h3 style="top:${bodyTop - 36}px">${title}</h3><p style="top:${bodyTop}px;height:${bodyHeight}px">${body}</p>${btns}</div>`);
}

function gkTouch(box, success) {
  const t = GK.touch;
  const fp = `<svg class="ico" viewBox="0 0 74 74"><circle cx="37" cy="37" r="32" fill="${success ? '#30d158' : 'url(#fpg)'}"/><defs><linearGradient id="fpg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff7aa8"/><stop offset="1" stop-color="#ff3b6e"/></linearGradient></defs>
    ${success ? '<path d="M24 38l9 9 18-20" stroke="#fff" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>' : '<g fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"><path d="M22 34c2-9 9-14 15-14s13 5 15 14"/><path d="M26 44c0-7 4-12 11-12s11 5 11 12v6"/><path d="M32 52c0-5 1-9 5-9s5 4 5 8"/><path d="M26 54c3 5 6 8 11 8"/></g>'}</svg>`;
  const btns = t.buttons.map((label, i) => `<div class="b" style="top:${box.h - 24 - 38 - (t.buttons.length - 1 - i) * 48}px">${label}</div>`).join('');
  return el(`<div class="gk gk-alert" style="${px(box)}">${fp}<p style="top:122px;height:170px;font-size:14px">${t.body}</p>${btns}</div>`);
}

function gkDock(t) {
  const pieces = DOCK_APPS.map((name, i) => {
    const lift = name === 'settings' ? hop(t, 9.9) : name === 'safari' ? hop(t, 2.3) * 0.7 : 0;
    const running = (name === 'safari') || (name === 'finder') || (name === 'settings' && t >= 10.2);
    return `<img src="assets/icons/${name}.png" style="position:absolute;left:${G.dockX0 + 14 + i * G.dockStep}px;top:${992 - lift}px;width:64px;height:64px;filter:drop-shadow(0 3px 4px rgba(0,0,0,.3))">${running ? `<i style="position:absolute;left:${G.dockX0 + 14 + i * G.dockStep + 30}px;top:1062px;width:5px;height:5px;border-radius:50%;background:rgba(255,255,255,.85)"></i>` : ''}`;
  }).join('');
  const W = 14 + DOCK_APPS.length * G.dockStep + 16 + 64 + 14;
  const sepX = G.dockX0 + 14 + DOCK_APPS.length * G.dockStep - 6;
  return el(`<div style="position:absolute;inset:0;z-index:60;pointer-events:none"><div style="position:absolute;left:${G.dockX0}px;top:980px;width:${W}px;height:88px;border-radius:30px;background:rgba(40,40,48,.55);border:1px solid rgba(255,255,255,.2);backdrop-filter:blur(30px)"></div>
    ${pieces}<div style="position:absolute;left:${sepX}px;top:994px;width:1px;height:60px;background:rgba(255,255,255,.28)"></div>
    <img src="assets/icons/trash.png" style="position:absolute;left:${sepX + 14}px;top:992px;width:64px;height:64px"></div>`);
}

// ---- The pointer: keyframes eased one after another, so it never jumps or stops dead
function pointer(path, t) {
  let a = path[0];
  if (t <= a.t) return a;
  for (let i = 1; i < path.length; i++) {
    const b = path[i];
    if (t <= b.t) { const k = ease(prog(t, a.t, b.t)); return { x: lerp(a.x, b.x, k), y: lerp(a.y, b.y, k) }; }
    a = b;
  }
  return a;
}
const PATH = () => [
  { t: 0, x: 1500, y: 760 }, { t: 0.7, x: 1500, y: 760 }, { t: 1.9, x: TARGET.download.x + 14, y: TARGET.download.y + 6 }, { t: 2.3, x: TARGET.download.x + 14, y: TARGET.download.y + 6 },
  { t: 4.6, x: TARGET.finderRow.x, y: TARGET.finderRow.y + 2 }, { t: 5.9, x: TARGET.finderRow.x, y: TARGET.finderRow.y + 2 },
  { t: 7.4, x: TARGET.a1Done.x + 10, y: TARGET.a1Done.y + 4 }, { t: 7.9, x: TARGET.a1Done.x + 10, y: TARGET.a1Done.y + 4 },
  { t: 9.9, x: TARGET.dockSettings.x, y: TARGET.dockSettings.y - 4 }, { t: 10.3, x: TARGET.dockSettings.x, y: TARGET.dockSettings.y - 4 },
  { t: 11.0, x: 560, y: 520 }, { t: 12.4, x: 560, y: 640 }, { t: 13.1, x: TARGET.privacyRow().x, y: TARGET.privacyRow().y }, { t: 13.5, x: TARGET.privacyRow().x, y: TARGET.privacyRow().y },
  { t: 15.8, x: TARGET.openAnyway.x, y: TARGET.openAnyway.y }, { t: 16.3, x: TARGET.openAnyway.x, y: TARGET.openAnyway.y },
  { t: 17.9, x: TARGET.a2Open.x + 12, y: TARGET.a2Open.y + 5 }, { t: 18.4, x: TARGET.a2Open.x + 12, y: TARGET.a2Open.y + 5 },
  { t: 20.0, x: 1180, y: 700 }, { t: 25.5, x: 1180, y: 700 },
];
const CLICKS = [2.2, 5.3, 5.55, 7.8, 10.1, 13.3, 16.1, 18.3];

const stepBadge = (i) => $(`<div class="gk-badge"><i>${i + 1}</i><span>${GK.steps[i]}</span></div>`);
const ringAt = (c, w, h) => $(`<div class="gk-ring" style="left:${c.x - w / 2}px;top:${c.y - h / 2}px;width:${w}px;height:${h}px"></div>`);

function sceneGK(t) {
  const finderIn = easeOut(prog(t, 3.3, 3.9));
  const finderSel = t >= 5.1;
  const dlProgress = prog(t, 2.4, 3.2);
  const a1 = easeOut(prog(t, 5.7, 6.1)) * (1 - ease(prog(t, 8.0, 8.3)));
  const setIn = easeOut(prog(t, 10.2, 10.9));
  const a2 = easeOut(prog(t, 16.3, 16.7)) * (1 - ease(prog(t, 18.6, 18.9)));
  const touchIn = easeOut(prog(t, 18.9, 19.3)) * (1 - ease(prog(t, 21.2, 21.5)));
  const touchOK = t >= 20.7;
  const welcomeIn = easeOut(prog(t, 21.7, 22.3));
  const layers = [];

  const safari = gkSafari(t >= 3.3, dlProgress);
  layers.push(safari);
  if (finderIn > 0) { const f = gkFinder(t >= 10.2, finderSel); f.style.opacity = finderIn.toFixed(3); f.style.transform = `scale(${lerp(0.94, 1, finderIn).toFixed(3)})`; layers.push(f); }
  if (setIn > 0) {
    const s = gkSettings(t);
    s.style.opacity = Math.min(1, setIn * 1.6).toFixed(3);
    s.style.transformOrigin = `${TARGET.dockSettings.x - G.settings.x}px ${TARGET.dockSettings.y - G.settings.y}px`;
    s.style.transform = `scale(${lerp(0.12, 1, setIn).toFixed(3)})`;
    layers.push(s);
  }
  layers.push(gkDock(t));
  if (a1 > 0.001) { const a = gkAlert(G.a1, GK.alert1.title, GK.alert1.body, GK.alert1.buttons, 0, 142, 110); a.style.opacity = a1.toFixed(3); a.style.transform = `scale(${lerp(0.94, 1, a1).toFixed(3)})`; layers.push(a); }
  if (a2 > 0.001) { const a = gkAlert(G.a2, GK.alert2.title, GK.alert2.body, GK.alert2.buttons, 0, 142, 220); a.style.opacity = a2.toFixed(3); a.style.transform = `scale(${lerp(0.94, 1, a2).toFixed(3)})`; layers.push(a); }
  if (touchIn > 0.001) { const a = gkTouch(G.touch, touchOK); a.style.opacity = touchIn.toFixed(3); a.style.transform = `scale(${lerp(0.94, 1, touchIn).toFixed(3)})`; layers.push(a); }
  if (welcomeIn > 0.001) {
    const w = el(`<img src="../../docs/media/shot-welcome-dark-${lang}.webp" style="position:absolute;left:${960 - 300}px;top:240px;width:600px;z-index:70;opacity:${welcomeIn.toFixed(3)};transform:scale(${lerp(0.93, 1, welcomeIn).toFixed(3)});filter:drop-shadow(0 30px 60px rgba(0,0,0,.55))">`);
    layers.push(w);
  }

  // the pointer, its clicks, the highlight rings
  const p = pointer(PATH(), t);
  const cursor = el(`<svg class="gk-cursor" viewBox="0 0 26 26" style="left:${(p.x - 3).toFixed(1)}px;top:${(p.y - 2).toFixed(1)}px"><path d="M4 2 L4 21 L9 16.5 L12.5 24 L16 22.5 L12.6 15 L19.5 15 Z" fill="#fff" stroke="#000" stroke-width="1.5" stroke-linejoin="round"/></svg>`);
  const ripples = CLICKS.map((c) => {
    const k = prog(t, c, c + 0.45);
    if (k <= 0 || k >= 1) return null;
    const pos = pointer(PATH(), c), r = 8 + 30 * easeOut(k);
    return el(`<div class="gk-click" style="left:${pos.x - r}px;top:${pos.y - r}px;width:${2 * r}px;height:${2 * r}px;opacity:${(1 - k).toFixed(2)}"></div>`);
  }).filter(Boolean);
  const rings = [];
  const ringWin = (a, b) => easeOut(prog(t, a, a + 0.25)) * (1 - ease(prog(t, b - 0.25, b)));
  const ringEl = (c, w, h, a, b) => { const v = ringWin(a, b); if (v > 0.01) { const r = ringAt(c, w, h); r.style.opacity = v.toFixed(3); rings.push(r); } };
  ringEl(TARGET.download, 290, 62, 1.0, 2.4);
  ringEl(TARGET.a1Done, 384, 48, 6.3, 8.0);
  ringEl(TARGET.dockSettings, 92, 92, 8.8, 10.2);
  ringEl(TARGET.privacyRow(), 264, 46, 12.9, 13.5);
  ringEl(TARGET.openAnyway, 160, 46, 15.0, 16.3);
  ringEl(TARGET.a2Open, 384, 48, 17.0, 18.5);

  // step badge
  const stepAt = [[0.5, 3.3, 0], [3.3, 5.5, 1], [5.5, 8.4, 2], [8.4, 15.0, 3], [15.0, 18.6, 4], [18.6, 21.5, 5], [21.5, 25.0, 6]];
  const badges = [];
  for (const [a, b, i] of stepAt) {
    const v = easeOut(prog(t, a, a + 0.3)) * (1 - ease(prog(t, b - 0.2, b)));
    if (v > 0.01) { const e = stepBadge(i); e.style.opacity = v.toFixed(3); e.style.transform = `translateY(${((1 - v) * 10).toFixed(1)}px)`; badges.push(e); }
  }
  const appName = t < 3.3 ? 'safari' : t < 10.2 ? 'finder' : 'settings';
  const showIcon = t >= 22.6;
  const iconPop = easeOut(prog(t, 22.6, 23.1));
  return {
    cam: { x: 960, y: 540, scale: 1 },
    layers: [...layers, ...rings, ...ripples, cursor],
    menubar: { app: appName, icon: showIcon ? 'moon' : null, clock: GK.clock, pulse: showIcon ? iconPop * (1 - ease(prog(t, 24, 24.6))) : 0 },
    overlays: badges,
    black: (1 - ease(prog(t, 0, 0.7))) * 0.97 + ease(prog(t, 25.0, 25.9)) * 0.97,
  };
}
SCENE_FNS.gk = sceneGK;
DURATIONS.gk = 25.9;
