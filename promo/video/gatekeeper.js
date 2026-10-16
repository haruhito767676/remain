// Scene "gk": how to open an app that Apple has not signed, drawn the way macOS 26 shows it (Safari, Finder, System Settings,
// the warning, the confirmation, Touch ID) with a pointer that moves smoothly. The icons are the real macOS icons, cut from a
// screen recording of the flow (promo/video/extract-gk-assets.py); the wording of the system screens is the real macOS wording
// in Japanese and an approximation in English; the account name and the Dock are made up.
//
//   node promo/video/record.mjs --lang ja gk        -> promo/video/out/clip-gk-ja.mp4

const GKT = {
  en: {
    clock: 'Fri Oct 17  3:17 PM',
    menus: { safari: ['Safari', 'File', 'Edit', 'View', 'History', 'Bookmarks', 'Window', 'Help'], settings: ['System Settings', 'Edit', 'View', 'Window', 'Help'] },
    site: { lead: 'Your Mac stays awake while AI agents work, and sleeps as usual when they are done.', download: 'Download for macOS', intro: 'Watch the intro' },
    finder: { title: 'Downloads', cols: ['Name', 'Size', 'Kind', 'Date Added'], row: ['remAIn', '6.5 MB', 'Application', 'Today at 3:17 PM'],
      side: [['f-recents', 'Recents'], ['f-shared', 'Shared'], ['h', 'Favorites'], ['f-apps', 'Applications'], ['f-desktop', 'Desktop'], ['f-docs', 'Documents'], ['f-downloads', 'Downloads', true], ['h', 'Locations'], ['f-icloud', 'iCloud Drive'], ['f-home', 'test'], ['f-disk', 'Macintosh HD'], ['f-airdrop', 'AirDrop']] },
    alert1: { title: '“remAIn” Not Opened', body: 'Apple could not verify “remAIn” is free of malware that may harm your Mac or compromise your privacy.', buttons: ['Move to Trash', 'Done'] },
    settings: {
      search: 'Search', name: 'Taro Yamada', account: 'Apple Account', notes: ['iCloud storage is almost full', 'Software updates available'],
      groups: [['Wi-Fi', 'Bluetooth', 'Network', 'VPN', 'Battery'], ['General', 'Accessibility', 'Siri', 'Spotlight', 'Displays', 'Desktop & Dock', 'Menu Bar', 'Appearance', 'Wallpaper'], ['Notifications', 'Sound', 'Focus', 'Screen Time'], ['Lock Screen', 'Privacy & Security', 'Touch ID & Password', 'Users & Groups'], ['Game Center', 'iCloud', 'Internet Accounts', 'Wallet & Apple Pay']],
      generalTitle: 'General', generalText: 'Manage your overall setup and preferences for Mac, such as software updates, device language, AirDrop and more.',
      privacy: 'Privacy & Security', infoTitle: 'Privacy', infoText: 'Manage how apps access your data, location, camera and microphone and keep it safe.', infoLink: 'Learn more…',
      location: ['Location Services', 'Off'],
      two: [['p-passkeys', 'Passkey Access for Web Browsers', 'None'], ['p-calendar', 'Calendars', 'None'], ['p-files', 'Files & Folders', '1 app'], ['p-disk', 'Full Disk Access', '1 app full access'], ['p-home', 'Home', 'None'], ['p-media', 'Media & Apple Music', 'None'], ['p-reminders', 'Reminders', 'None'], ['p-photos', 'Photos', 'None']],
      single: [['p-bluetooth', 'Bluetooth', '1'], ['p-remote', 'Remote Desktop', '0'], ['p-appmgmt', 'App Management', '0'], ['p-automation', 'Automation', '0'], ['p-camera', 'Camera', '0'], ['p-devices', 'Devices & Data Access', '10'], ['p-devtools', 'Developer Tools', '0'], ['p-mic', 'Microphone', '0'], ['p-motion', 'Motion & Fitness', '0'], ['p-localnet', 'Local Network', '0'], ['p-speech', 'Speech Recognition', '0'], ['p-screenrec', 'Screen & System Audio Recording', '5'], ['p-focus', 'Focus', '0']],
      blockedContacts: ['p-blocked', 'Blocked Contacts', ''], analytics: [['p-analytics', 'Analytics & Improvements', ''], ['p-ads', 'Apple Advertising', '']], ai: ['p-ai', 'Apple Intelligence Report', 'On'],
      security: 'Security', allow: ['Allow applications from', 'App Store & Known Developers'],
      blocked: '“remAIn” was blocked to protect your Mac.', blockedSub: 'Apple could not verify “remAIn” is free of malware that may harm your Mac or compromise your privacy.', openAnyway: 'Open Anyway',
      after: [['p-filevault', 'FileVault', 'On'], ['p-accessory', 'Accessories', 'Ask every time'], ['p-bgsec', 'Background Security Improvements', '']],
    },
    alert2: { title: 'Open “remAIn”?', body: 'Apple is not able to verify that “remAIn” is free from malware that may harm your Mac or compromise your privacy. Unless you trust the source of this app, you shouldn’t open it.', buttons: ['Move to Trash', 'Open Anyway', 'Done'] },
    touch: { title: 'You are about to open an app that may harm your Mac or compromise your privacy', body: 'To continue in Privacy & Security, use Touch ID or enter your administrator name and password.', buttons: ['Use Password…', 'Cancel'] },
    steps: ['Download', 'Open it', 'If a warning appears, click “Done”', 'System Settings → Privacy & Security', 'Click “Open Anyway”', 'Confirm with Touch ID or your password', 'It opens'],
  },
  ja: {
    clock: '10月17日(金)  15:17',
    menus: { safari: ['Safari', 'ファイル', '編集', '表示', '履歴', 'ブックマーク', 'ウインドウ', 'ヘルプ'], settings: ['システム設定', '編集', '表示', 'ウインドウ', 'ヘルプ'] },
    site: { lead: 'AIエージェントが働いているあいだだけ、Macを起こしておきます。終われば、いつもどおりスリープします。', download: 'macOS版をダウンロード', intro: '紹介動画を見る' },
    finder: { title: 'ダウンロード', cols: ['名前', 'サイズ', '種類', '追加日'], row: ['remAIn', '6.5 MB', 'アプリケーション', '今日 15:17'],
      side: [['f-recents', '最近の項目'], ['f-shared', '共有'], ['h', 'よく使う項目'], ['f-apps', 'アプリケーション'], ['f-desktop', 'デスクトップ'], ['f-docs', '書類'], ['f-downloads', 'ダウンロード', true], ['h', '場所'], ['f-icloud', 'iCloud Drive'], ['f-home', 'test'], ['f-disk', 'Macintosh HD'], ['f-airdrop', 'AirDrop']] },
    alert1: { title: '“remAIn”は開いていません', body: 'Appleは、“remAIn”にMacに損害を与えたり、プライバシーを侵害する可能性のあるマルウェアが含まれていないことを検証できませんでした。', buttons: ['ゴミ箱に入れる', '完了'] },
    settings: {
      search: '検索', name: '山田 太郎', account: 'Apple Account', notes: ['iCloudストレージが残りわずかです', 'ソフトウェアアップデートが入手可能'],
      groups: [['Wi-Fi', 'Bluetooth', 'ネットワーク', 'VPN', 'バッテリー'], ['一般', 'アクセシビリティ', 'Siri', 'Spotlight', 'ディスプレイ', 'デスクトップとDock', 'メニューバー', '外観', '壁紙'], ['通知', 'サウンド', '集中モード', 'スクリーンタイム'], ['ロック画面', 'プライバシーとセキュリティ', 'Touch IDとパスワード', 'ユーザとグループ'], ['Game Center', 'iCloud', 'インターネットアカウント', 'ウォレットとApple Pay']],
      generalTitle: '一般', generalText: 'ソフトウェアアップデート、デバイスの言語、AirDropなど、Macの全体的な設定や自分の好みの設定を管理します。',
      privacy: 'プライバシーとセキュリティ', infoTitle: 'プライバシー', infoText: 'どのアプリがあなたのデータ、位置情報、カメラ、およびマイクにアクセスできるかを管理し、安全保護を管理します。', infoLink: '詳しい情報…',
      location: ['位置情報サービス', 'オフ'],
      two: [['p-passkeys', 'ウェブブラウザのパスキーへのアクセス', 'なし'], ['p-calendar', 'カレンダー', 'なし'], ['p-files', 'ファイルとフォルダ', '1個のアプリ'], ['p-disk', 'フルディスクアクセス', 'フルアクセス1個'], ['p-home', 'ホーム', 'なし'], ['p-media', 'メディアとApple Music', 'なし'], ['p-reminders', 'リマインダー', 'なし'], ['p-photos', '写真', 'なし']],
      single: [['p-bluetooth', 'Bluetooth', '1'], ['p-remote', 'Remote Desktop', '0'], ['p-appmgmt', 'アプリ管理', '0'], ['p-automation', 'オートメーション', '0'], ['p-camera', 'カメラ', '0'], ['p-devices', 'デバイスの制御とデータへのアクセス', '10'], ['p-devtools', 'デベロッパツール', '0'], ['p-mic', 'マイク', '0'], ['p-motion', 'モーションとフィットネス', '0'], ['p-localnet', 'ローカルネットワーク', '0'], ['p-speech', '音声認識', '0'], ['p-screenrec', '画面収録とシステムオーディオ録音', '5'], ['p-focus', '集中モード', '0']],
      blockedContacts: ['p-blocked', '拒否した連絡先', ''], analytics: [['p-analytics', '解析と改善', ''], ['p-ads', 'Appleの広告', '']], ai: ['p-ai', 'Apple Intelligenceレポート', 'オン'],
      security: 'セキュリティ', allow: ['アプリケーションの実行許可', 'App Storeと既知のデベロッパ'],
      blocked: 'お使いのMacを保護するために“remAIn”がブロックされました。', blockedSub: 'Appleは、“remAIn”にMacに損害を与えたり、プライバシーを侵害する可能性のあるマルウェアが含まれていないことを検証できませんでした。', openAnyway: 'このまま開く',
      after: [['p-filevault', 'FileVault', 'オン'], ['p-accessory', 'アクセサリ', '毎回確認'], ['p-bgsec', 'バックグラウンドセキュリティ改善', '']],
    },
    alert2: { title: '“remAIn”を開きますか?', body: 'Appleは、このアプリにMacに損害を与えたり、プライバシーを侵害する可能性のあるマルウェアが含まれていないことを検証できません。信頼できる提供元からのものであることが確認できない限り、このアプリを開いていないでください。', buttons: ['ゴミ箱に入れる', 'このまま開く', '完了'] },
    touch: { title: 'Macに損害を与えたり、プライバシーを侵害する可能性のあるアプリを開こうとしています', body: 'プライバシーとセキュリティで続けるには、Touch IDを使用するか、管理者の名前とパスワードを入力してください。', buttons: ['パスワードを使用…', 'キャンセル'] },
    steps: ['ダウンロードする', '開く', '警告が出たら「完了」を押す', 'システム設定 → プライバシーとセキュリティ', '「このまま開く」を押す', 'Touch IDかパスワードで認証', '開けました'],
  },
};
const GK = GKT[lang] || GKT.en;
Object.assign(T.menus, GK.menus);
const icon = (name, cls = '') => `<img src="assets/gk/${name}.png" ${cls ? `class="${cls}"` : ''}>`;

// ---- Geometry (everything the pointer needs to find)
const G = {
  safari: { x: 300, y: 130, w: 1320, h: 750 },
  finder: { x: 420, y: 200, w: 1080, h: 560 },
  settings: { x: 400, y: 120, w: 1120, h: 830 },
  a1: { x: 790, y: 240, w: 340, h: 400 },
  a2: { x: 785, y: 170, w: 350, h: 570 },
  touch: { x: 790, y: 230, w: 340, h: 430 },
  dockStep: 74,
};
const DOCK_APPS = ['finder', 'safari', 'mail', 'messages', 'maps', 'photos', 'facetime', 'calendar', 'contacts', 'notes', 'music', 'appstore', 'settings'];
G.dockX0 = (1920 - (14 + DOCK_APPS.length * G.dockStep + 16 + 64 + 14)) / 2;
const dockCenter = (name) => ({ x: G.dockX0 + 14 + DOCK_APPS.indexOf(name) * G.dockStep + 32, y: 1024 });

// System Settings' sidebar: the y of every row inside its scroll area
const SIDEBAR_ICONS = [['wifi', 'bluetooth', 'network', 'vpn', 'battery'], ['general', 'accessibility', 'siri', 'spotlight', 'displays', 'desktopdock', 'menubar', 'appearance', 'wallpaper'], ['notifications', 'sound', 'focus', 'screentime'], ['lockscreen', 'privacy', 'touchid', 'users'], ['gamecenter', 'icloud', 'internetaccounts', 'wallet']];
function sidebarLayout() {
  const rows = []; let y = 38 + 12 + 62 + 2 * 52 + 14;
  GK.settings.groups.forEach((g, gi) => { if (gi) y += 14; g.forEach((name, i) => { rows.push({ name, icon: SIDEBAR_ICONS[gi][i], y }); y += 38; }); });
  return rows;
}
const privacyRow = () => sidebarLayout().find((r) => r.name === GK.settings.privacy);
const SIDEBAR_SCROLL = 380;

// the Privacy & Security pane: stacked cards; `y` is where each starts inside the pane
function paneLayout() {
  const s = GK.settings; let y = 24; const L = {};
  L.info = y; y += 112 + 16;
  L.location = y; y += 56 + 16;
  L.two = y; y += s.two.length * 60 + 16;
  L.single = y; y += s.single.length * 52 + 16;
  L.blockedContacts = y; y += 52 + 16;
  L.analytics = y; y += s.analytics.length * 52 + 16;
  L.ai = y; y += 52 + 28;
  L.securityTitle = y; y += 30;
  L.allow = y; y += 56 + 16;
  L.block = y; y += 150 + 16;
  L.after = y; y += s.after.length * 52 + 40;
  L.total = y;
  return L;
}
const PANE_SCROLL = () => paneLayout().block - 330;

const TARGET = {
  download: { x: G.safari.x + 402 + 125, y: G.safari.y + 60 + 406 + 25 },
  finderRow: { x: G.finder.x + 232 + 120, y: G.finder.y + 100 + 17 },
  a1Done: { x: G.a1.x + G.a1.w / 2, y: G.a1.y + G.a1.h - 24 - 20 },
  dockSettings: dockCenter('settings'),
  privacyRow: () => ({ x: G.settings.x + 12 + 130, y: G.settings.y + 64 + privacyRow().y - SIDEBAR_SCROLL + 19 }),
  openAnyway: () => ({ x: G.settings.x + 290 + 24 + (782 - 18 - 66), y: G.settings.y + 60 + (paneLayout().block - PANE_SCROLL()) + 20 + 17 }),
  a2Open: { x: G.a2.x + G.a2.w / 2, y: G.a2.y + G.a2.h - 24 - 40 - 50 + 20 },
};

// ---- Pieces
const el = (html) => $(html.trim());
const px = (o) => `left:${o.x}px;top:${o.y}px;width:${o.w}px;height:${o.h}px`;
const lights = '<div class="lights"><i></i><i></i><i></i></div>';
const chev = (d) => `<svg width="14" height="20" viewBox="0 0 14 20" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"/></svg>`;
const BACK = chev('M10 3 L3 10 L10 17'), FWD = chev('M4 3 L11 10 L4 17');

function gkSafari(off, dlProgress) {
  const g = G.safari, s = GK.site;
  const dl = dlProgress > 0 ? `<div class="dl" style="opacity:${Math.min(1, dlProgress * 6).toFixed(2)}"><svg width="30" height="30" viewBox="0 0 30 30"><circle cx="15" cy="15" r="11" fill="none" stroke="rgba(255,255,255,.2)" stroke-width="3"/><circle cx="15" cy="15" r="11" fill="none" stroke="#7fb2ff" stroke-width="3" stroke-linecap="round" stroke-dasharray="${(69 * Math.min(1, dlProgress)).toFixed(1)} 100" transform="rotate(-90 15 15)"/><path d="M15 9v9m-4-3 4 4 4-4" stroke="#7fb2ff" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round" opacity="${dlProgress >= 1 ? 1 : 0}"/></svg></div>` : '';
  const sidebarIcon = '<svg width="22" height="18" viewBox="0 0 22 18" fill="none" stroke="currentColor" stroke-width="2"><rect x="1.5" y="1.5" width="19" height="15" rx="4"/><path d="M8 2v14"/></svg>';
  const share = '<svg width="20" height="22" viewBox="0 0 20 22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 14V2M6 6l4-4 4 4M3 10v9h14v-9"/></svg>';
  const plus = '<svg width="18" height="18" viewBox="0 0 18 18" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M9 2v14M2 9h14"/></svg>';
  const tabs = '<svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2"><rect x="6" y="2" width="12" height="12" rx="3"/><path d="M2 6v9a3 3 0 003 3h9"/></svg>';
  return el(`<div class="gk gk-safari ${off ? 'off' : ''}" style="${px(g)}">${lights}<div class="bar">
      <div class="pill" style="left:116px;top:10px;width:46px">${sidebarIcon}</div>
      <div class="pill" style="left:174px;top:10px;width:84px;gap:14px">${BACK}${FWD}</div>
      <div class="url">haruhito767676.github.io</div>${dl}
      <div class="pill" style="right:70px;top:10px;width:44px">${share}</div><div class="pill" style="right:18px;top:10px;width:44px">${plus}</div>
      <div class="pill" style="right:122px;top:10px;width:0;border:0;background:none"></div></div>
    <div class="page"><div class="nav"><img src="assets/icons/remain.png">remAIn</div><img class="gkicon" src="assets/icons/remain.png">
      <h1>rem<b>AI</b>n</h1><p>${s.lead}</p><div class="btn a">${s.download}</div><div class="btn b">${s.intro}</div></div></div>`);
}

function gkFinder(off, selected) {
  const g = G.finder, f = GK.finder;
  const side = f.side.map(([ic, label, sel]) => ic === 'h' ? `<h6>${label}</h6>` : `<div class="${sel ? 'sel' : ''}">${icon(ic)}${label}</div>`).join('');
  const grid = '<svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="6" height="6" rx="1.5"/><rect x="12" y="2" width="6" height="6" rx="1.5"/><rect x="2" y="12" width="6" height="6" rx="1.5"/><rect x="12" y="12" width="6" height="6" rx="1.5"/></svg>';
  const list = '<svg width="22" height="18" viewBox="0 0 22 18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M7 3h13M7 9h13M7 15h13"/><circle cx="2.5" cy="3" r=".8"/><circle cx="2.5" cy="9" r=".8"/><circle cx="2.5" cy="15" r=".8"/></svg>';
  return el(`<div class="gk gk-finder ${off ? 'off' : ''}" style="${px(g)}">${lights}<div class="side">${side}</div>
    <div class="main"><div class="tb"><div class="nav">${BACK}${FWD}</div>${f.title}</div>
      <div class="views"><div class="pill">${grid}</div><div class="pill on">${list}</div></div>
      <div class="head"><span class="c1">${f.cols[0]}</span><span class="c2">${f.cols[1]}</span><span class="c3">${f.cols[2]}</span><span class="c4">${f.cols[3]}</span></div>
      <div class="row ${selected ? 'sel' : ''}"><span class="c1"><img src="assets/icons/remain-small.png" style="position:absolute;margin-left:-30px">${f.row[0]}</span><span class="c2">${f.row[1]}</span><span class="c3">${f.row[2]}</span><span class="c4">${f.row[3]}</span></div>
      <div class="stripes"></div></div></div>`);
}

function paneHtml(scroll) {
  const s = GK.settings, L = paneLayout();
  const row = (ic, title, value, top, h, extra = '', sub = '') => `<div class="r ${extra}" style="top:${top}px;height:${h}px"><span class="l">${icon(ic)}<span class="t">${title}${sub ? `<small>${sub}</small>` : ''}</span></span><em>${value || ''}</em></div>`;
  const card = (top, h, inner, cls = '') => `<div class="card ${cls}" style="top:${top}px;height:${h}px">${inner}</div>`;
  const rowsOf = (list, rh, withSub) => list.map((r, i) => withSub ? row(r[0], r[1], '', i * rh, rh, '', r[2]) : row(r[0], r[1], r[2], i * rh, rh)).join('');
  return `<div class="pane" style="transform:translateY(${-scroll.toFixed(1)}px)">
    ${card(L.info, 112, `<div class="info">${icon('p-hand')}<div><b>${s.infoTitle}</b><span>${s.infoText} <a>${s.infoLink}</a></span></div></div>`)}
    ${card(L.location, 56, row('p-location', s.location[0], s.location[1], 0, 56))}
    ${card(L.two, s.two.length * 60, rowsOf(s.two, 60, true))}
    ${card(L.single, s.single.length * 52, rowsOf(s.single, 52, false))}
    ${card(L.blockedContacts, 52, row(...[s.blockedContacts[0], s.blockedContacts[1], s.blockedContacts[2], 0, 52]))}
    ${card(L.analytics, s.analytics.length * 52, rowsOf(s.analytics, 52, false))}
    ${card(L.ai, 52, row(s.ai[0], s.ai[1], s.ai[2], 0, 52))}
    <h5 style="top:${L.securityTitle}px">${s.security}</h5>
    ${card(L.allow, 56, `<div class="r nochev" style="top:0;height:56px"><span>${s.allow[0]}</span><em>${s.allow[1]}</em></div>`)}
    ${card(L.block, 150, `<div class="msg">${s.blocked}</div><div class="sub">${s.blockedSub}</div><div class="btn2" style="left:${782 - 18 - 132}px;top:20px;width:132px">${s.openAnyway}</div>`, 'block')}
    ${card(L.after, s.after.length * 52, rowsOf(s.after, 52, false))}</div>`;
}

function gkSettings(t) {
  const g = G.settings, s = GK.settings;
  const onPrivacy = t >= 13.3;
  const sideScroll = ease(prog(t, 11.0, 12.5)) * SIDEBAR_SCROLL;
  const rows = sidebarLayout();
  let n = 0;
  const items = s.groups.map((grp, gi) => (gi ? '<div class="gap"></div>' : '') + grp.map((name) => {
    const r = rows[n++];
    const sel = onPrivacy ? name === s.privacy : name === s.groups[1][0];
    return `<div class="item ${sel ? 'sel' : ''}">${icon(r.icon)}${name}</div>`;
  }).join('')).join('');
  const scroll = ease(prog(t, 13.9, 16.1)) * PANE_SCROLL();
  const general = `<div class="general"><img src="assets/icons/settings.png"><b>${s.generalTitle}</b><p>${s.generalText}</p></div>`;
  const fade = ease(prog(t, 13.3, 13.7));
  const notes = s.notes.map((x) => `<div class="note"><span>${x}</span><i>1</i></div>`).join('');
  return el(`<div class="gk gk-settings" style="${px(g)}">${lights}
    <div class="side"><div class="scroll"><div style="transform:translateY(${-sideScroll.toFixed(1)}px)"><div class="search">${s.search}</div>
      <div class="profile"><div class="av"></div><div><b>${s.name}</b><span>${s.account}</span></div></div>${notes}<div style="height:14px"></div>${items}</div></div></div>
    <div class="content"><div class="topbar"><span class="nv">${BACK}${FWD}</span>${onPrivacy ? s.privacy : s.generalTitle}</div>
      <div style="position:absolute;inset:0;opacity:${(1 - fade).toFixed(3)}">${general}</div>
      <div style="position:absolute;inset:0;opacity:${fade.toFixed(3)}">${paneHtml(scroll)}</div></div></div>`);
}

function gkAlert(box, title, body, buttons, primary, bodyTop, bodyHeight, helpButton = true) {
  const bh = 40, gap = 10;
  const btns = buttons.map((label, i) => {
    const fromBottom = buttons.length - 1 - i;
    return `<div class="b ${i === primary ? 'p' : ''}" style="top:${box.h - 24 - bh - fromBottom * (bh + gap)}px">${label}</div>`;
  }).join('');
  return el(`<div class="gk gk-alert" style="${px(box)}">${icon('gatekeeper', 'ico')}${helpButton ? '<div class="help">?</div>' : ''}<h3 style="top:${bodyTop - 44}px">${title}</h3><p style="top:${bodyTop}px;height:${bodyHeight}px">${body}</p>${btns}</div>`);
}

function gkTouch(box, success) {
  const t = GK.touch;
  const ico = success
    ? '<svg class="ico" viewBox="0 0 84 84" style="width:84px"><circle cx="42" cy="42" r="40" fill="#30d158"/><path d="M26 43l11 11 21-24" stroke="#fff" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    : icon('touchid-prompt', 'ico');
  const btns = t.buttons.map((label, i) => `<div class="b" style="top:${box.h - 24 - 40 - (t.buttons.length - 1 - i) * 50}px">${label}</div>`).join('');
  return el(`<div class="gk gk-alert" style="${px(box)}">${ico}<h3 style="top:128px;font-size:17px">${t.title}</h3><p style="top:208px;height:120px">${t.body}</p>${btns}</div>`);
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
const PATH = () => {
  const oa = TARGET.openAnyway(), pr = TARGET.privacyRow();
  return [
    { t: 0, x: 1500, y: 760 }, { t: 0.7, x: 1500, y: 760 }, { t: 1.9, x: TARGET.download.x + 14, y: TARGET.download.y + 6 }, { t: 2.3, x: TARGET.download.x + 14, y: TARGET.download.y + 6 },
    { t: 4.6, x: TARGET.finderRow.x, y: TARGET.finderRow.y + 2 }, { t: 5.9, x: TARGET.finderRow.x, y: TARGET.finderRow.y + 2 },
    { t: 7.4, x: TARGET.a1Done.x + 10, y: TARGET.a1Done.y + 4 }, { t: 7.9, x: TARGET.a1Done.x + 10, y: TARGET.a1Done.y + 4 },
    { t: 9.9, x: TARGET.dockSettings.x, y: TARGET.dockSettings.y - 4 }, { t: 10.3, x: TARGET.dockSettings.x, y: TARGET.dockSettings.y - 4 },
    { t: 11.0, x: 560, y: 520 }, { t: 12.4, x: 560, y: 640 }, { t: 13.1, x: pr.x, y: pr.y }, { t: 13.5, x: pr.x, y: pr.y },
    { t: 14.2, x: 1100, y: 560 }, { t: 16.5, x: oa.x, y: oa.y }, { t: 16.9, x: oa.x, y: oa.y },
    { t: 18.4, x: TARGET.a2Open.x + 12, y: TARGET.a2Open.y + 5 }, { t: 18.9, x: TARGET.a2Open.x + 12, y: TARGET.a2Open.y + 5 },
    { t: 20.4, x: 1180, y: 740 }, { t: 26.3, x: 1180, y: 740 },
  ];
};
const CLICKS = [2.2, 5.3, 5.55, 7.8, 10.1, 13.3, 16.8, 18.8];

const stepBadge = (i) => $(`<div class="gk-badge"><i>${i + 1}</i><span>${GK.steps[i]}</span></div>`);
const ringAt = (c, w, h) => $(`<div class="gk-ring" style="left:${c.x - w / 2}px;top:${c.y - h / 2}px;width:${w}px;height:${h}px"></div>`);

function sceneGK(t) {
  const finderIn = easeOut(prog(t, 3.3, 3.9));
  const finderSel = t >= 5.1;
  const dlProgress = prog(t, 2.4, 3.2);
  const a1 = easeOut(prog(t, 5.7, 6.1)) * (1 - ease(prog(t, 8.0, 8.3)));
  const setIn = easeOut(prog(t, 10.2, 10.9));
  const a2 = easeOut(prog(t, 17.0, 17.4)) * (1 - ease(prog(t, 19.0, 19.3)));
  const touchIn = easeOut(prog(t, 19.5, 19.9)) * (1 - ease(prog(t, 21.9, 22.2)));
  const touchOK = t >= 21.3;
  const welcomeIn = easeOut(prog(t, 22.4, 23.0));
  const layers = [];

  layers.push(gkSafari(t >= 3.3, dlProgress));
  if (finderIn > 0) { const f = gkFinder(t >= 10.2, finderSel); f.style.opacity = finderIn.toFixed(3); f.style.transform = `scale(${lerp(0.94, 1, finderIn).toFixed(3)})`; layers.push(f); }
  if (setIn > 0) {
    const s = gkSettings(t);
    s.style.opacity = Math.min(1, setIn * 1.6).toFixed(3);
    s.style.transformOrigin = `${TARGET.dockSettings.x - G.settings.x}px ${TARGET.dockSettings.y - G.settings.y}px`;
    s.style.transform = `scale(${lerp(0.12, 1, setIn).toFixed(3)})`;
    layers.push(s);
  }
  layers.push(gkDock(t));
  const pop = (a, v) => { a.style.opacity = v.toFixed(3); a.style.transform = `scale(${lerp(0.94, 1, v).toFixed(3)})`; layers.push(a); };
  if (a1 > 0.001) pop(gkAlert(G.a1, GK.alert1.title, GK.alert1.body, GK.alert1.buttons, 0, 168, 130), a1);
  if (a2 > 0.001) pop(gkAlert(G.a2, GK.alert2.title, GK.alert2.body, GK.alert2.buttons, 0, 168, 250), a2);
  if (touchIn > 0.001) pop(gkTouch(G.touch, touchOK), touchIn);
  if (welcomeIn > 0.001) {
    layers.push(el(`<img src="../../docs/media/shot-welcome-dark-${lang}.webp" style="position:absolute;left:${960 - 300}px;top:240px;width:600px;z-index:70;opacity:${welcomeIn.toFixed(3)};transform:scale(${lerp(0.93, 1, welcomeIn).toFixed(3)});filter:drop-shadow(0 30px 60px rgba(0,0,0,.55))">`));
  }

  // the pointer, its clicks, the highlight rings
  const p = pointer(PATH(), t);
  const cursor = el(`<svg class="gk-cursor" viewBox="0 0 26 26" style="left:${(p.x - 3).toFixed(1)}px;top:${(p.y - 2).toFixed(1)}px"><path d="M4 2 L4 21 L9 16.5 L12.5 24 L16 22.5 L12.6 15 L19.5 15 Z" fill="#000" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/></svg>`);
  const ripples = CLICKS.map((c) => {
    const k = prog(t, c, c + 0.45);
    if (k <= 0 || k >= 1) return null;
    const pos = pointer(PATH(), c), r = 8 + 30 * easeOut(k);
    return el(`<div class="gk-click" style="left:${pos.x - r}px;top:${pos.y - r}px;width:${2 * r}px;height:${2 * r}px;opacity:${(1 - k).toFixed(2)}"></div>`);
  }).filter(Boolean);
  const rings = [];
  const ringEl = (c, w, h, a, b) => {
    const v = easeOut(prog(t, a, a + 0.25)) * (1 - ease(prog(t, b - 0.25, b)));
    if (v > 0.01) { const r = ringAt(c, w, h); r.style.opacity = v.toFixed(3); rings.push(r); }
  };
  ringEl(TARGET.download, 290, 62, 1.0, 2.4);
  ringEl(TARGET.a1Done, 340, 52, 6.3, 8.0);
  ringEl(TARGET.dockSettings, 92, 92, 8.8, 10.2);
  ringEl(TARGET.privacyRow(), 264, 46, 12.9, 13.5);
  ringEl(TARGET.openAnyway(), 160, 46, 15.6, 17.0);
  ringEl(TARGET.a2Open, 340, 52, 17.5, 19.0);

  const stepAt = [[0.5, 3.3, 0], [3.3, 5.5, 1], [5.5, 8.4, 2], [8.4, 16.4, 3], [16.4, 19.5, 4], [19.5, 22.4, 5], [22.4, 26.0, 6]];
  const badges = [];
  for (const [a, b, i] of stepAt) {
    const v = easeOut(prog(t, a, a + 0.3)) * (1 - ease(prog(t, b - 0.2, b)));
    if (v > 0.01) { const e = stepBadge(i); e.style.opacity = v.toFixed(3); e.style.transform = `translateY(${((1 - v) * 10).toFixed(1)}px)`; badges.push(e); }
  }
  const appName = t < 3.3 ? 'safari' : t < 10.2 ? 'finder' : 'settings';
  const showIcon = t >= 23.0;
  const iconPop = easeOut(prog(t, 23.0, 23.5));
  return {
    cam: { x: 960, y: 540, scale: 1 },
    layers: [...layers, ...rings, ...ripples, cursor],
    menubar: { app: appName, icon: showIcon ? 'moon' : null, clock: GK.clock, pulse: showIcon ? iconPop * (1 - ease(prog(t, 24.4, 25.0))) : 0 },
    overlays: badges,
    black: (1 - ease(prog(t, 0, 0.7))) * 0.97 + ease(prog(t, 25.4, 26.3)) * 0.97,
  };
}
SCENE_FNS.gk = sceneGK;
DURATIONS.gk = 26.3;
