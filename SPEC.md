# remAIn 技術仕様書 (SPEC)

本書は remAIn の内部仕様（構成、イベントモデル、各ツールとの連携、スリープ制御、電源ガード、ふた閉じモード、アクティビティログ、IPC、CLI、UI、ビルドと配布）を定義する。利用者向けの説明は README を参照。対象バージョン: 1.0.0。

---

## 1. アーキテクチャ概要

```
 Claude Code / Codex / Antigravity            任意のコマンド
        │ フック (stdin に JSON)                  │ remain run -- <cmd>
        ▼                                         ▼
 ┌─────────────────────────── remain (CLI) ───────────────────────────┐
 │  hook: 入力を AgentEvent に正規化 → 監視対象プロセスと transcript    │
 │        サイズを付与 → Unix ドメインソケットで送信                    │
 └────────────────────────────────┬───────────────────────────────────┘
                                  │ ~/Library/Application Support/remAIn/remain.sock
                                  ▼
 ┌──────────────────────── remAIn.app (メニューバー) ─────────────────┐
 │  IPCServer ─▶ WakeCoordinator ─▶ WakeEngine (純粋な状態機械)         │
 │                 │   ├─ IOKitSleepAssertions (IOPMAssertion)          │
 │                 │   ├─ LidSleepController ─▶ pmset / watchdog        │
 │                 │   ├─ ActivityLog (JSON Lines)                      │
 │                 │   └─ 生存確認ポーリング (3 秒)                      │
 │  SystemPowerMonitor ─▶ 電池 / 低電力 / 熱 / ふた                      │
 │  SwiftUI: MenuBarExtra / Settings / ウェルカム / About               │
 └────────────────────────────────────────────────────────────────────┘
```

- 外部依存パッケージなし。Swift 6、SwiftPM、macOS 14 以降。通信は同一 Mac 内のソケットのみで、ネットワークには接続しない。
- **判断はすべて `WakeEngine` に集める。** 時刻は引数で渡すので、決定的にテストできる。OS への反映（アサーション、`pmset`）と時間の管理は `WakeCoordinator` が担う。

### 1.1 ターゲット

| ターゲット | 種別 | 役割 |
|---|---|---|
| `RemainCore` | ライブラリ | エンジン、イベント、連携、ふた閉じ、ログ、IPC。UI を持たない |
| `remain` | 実行ファイル (CLI) | フックの受け口、`status` `on` `off` `run` `doctor` など |
| `RemainApp` | 実行ファイル (アプリ) | メニューバー、設定、通知、ログイン項目 |
| `RemainCoreTests` | テスト | Swift Testing。191 件 |

CLI はアプリ内の `Contents/Helpers/remain` に同梱される。フックが呼ぶのはこの実行ファイルの絶対パスである。

---

## 2. イベントモデル

各ツールのフックは `AgentEvent` に正規化される。

| `Kind` | 意味 | エンジンの動き |
|---|---|---|
| `prompt` | 利用者がプロンプトを送った | セッションを新規作成（既存は作り直し）。`working` |
| `start` | モデル呼び出しの開始（`prompt` 相当のフックがないツール用） | 既存セッションを更新、なければ作成。`background` を解除 |
| `activity` | 動作中（ツール実行など） | 既存セッションの `lastSeen` を更新。**未知のセッションは無視** |
| `background` | 一旦止まったが、バックグラウンドで作業が続く | `background = true`。沈黙タイムアウトの短縮を外す |
| `attention` | 利用者の入力待ち（許可ダイアログ等） | `waiting` へ。作業中からの遷移のとき `needsAttention` を通知 |
| `finish` | 完了・失敗・セッション終了 | セッションを外す。最初の 1 回だけ `sessionFinished` を通知 |
| `interrupted` | 利用者が中断した（ツールが直接教える場合） | 静かに外す（通知・完了アクションなし） |

`activity` が未知のセッションを無視するのは意図的である。`Stop` のあとに遅れて届いたフックが、終わったセッションを復活させないため。

### 2.1 セッション

```
AgentSession { id, phase(working|waiting), startedAt, lastSeen, cwd,
               pid, transcriptPath, scanOffset, agent, background }
```

- 識別子はツールごとのセッション ID（Claude/Codex: `session_id`、Antigravity: `conversationId`、`remain run`: `run-<8 桁>`）。複数の並列セッションを同時に追える。
- `cwd` の最後の要素（フォルダ名）だけが、通知とログに使われる。フルパスは保存しない。

---

## 3. ツール連携

連携とは、各ツールの設定ファイルに remAIn のフックを書き込むことである。書き込み・削除は、remAIn が書いた項目だけを対象とする。

| ツール | 設定ファイル | フックイベント |
|---|---|---|
| Claude Code | `~/.claude/settings.json` | `UserPromptSubmit` `PreToolUse` `PostToolUse` `Notification` `Stop` `StopFailure` `SessionEnd` |
| Codex | `~/.codex/hooks.json` | `UserPromptSubmit` `PreToolUse` `PostToolUse` `PermissionRequest` `Stop` `Interrupt` `SessionEnd` |
| Antigravity | `~/.gemini/config/hooks.json` | `SessionStart` `PreInvocation` `PostInvocation` `Stop` `PostToolUse` |

- フックのコマンドは `'<remain の絶対パス>' hook`（Codex は `hook codex`、Antigravity は `hook antigravity <Event>`）。タイムアウトは 5 秒、Codex の `SessionEnd` と `Interrupt` は 3 秒（Codex が長い値を丸めて毎回警告するため）。
- Claude Code と Codex は同じ `{"hooks": {イベント: [{hooks: [...]}]}}` 形式。Antigravity はトップレベルのキーがフック名で、remAIn は `remain` というキー 1 つだけを持つ。Antigravity の `PreToolUse` は判断（allow/deny）を返す必要があるため、触れない。
- **既存の設定を壊さない**: 他のフックと他のキーはそのまま残す。書き出しは原子的で、元のファイルは `<名前>.remain-backup` に一度だけコピーする。JSON として読めないファイルは上書きせず、エラーとして報告する。
- 判定は `IntegrationState`: `notDetected`（ツールが見つからない）/ `notInstalled` / `installed` / `needsRepair`（フックが別の remAIn を指している）。ツールの検出は、データフォルダまたはアプリの有無で行い、ツール自体は実行しない。
- `needsRepair` は、アプリが移動された場合に起きる。アプリは起動時に、バンドルされた状態であれば自動で修復する（開発中のビルドは対象外）。
- アプリの設定画面では、ツールごとのトグルがインストール／削除に対応する。`needsRepair` では「修復」ボタンが出る。

### 3.1 フックが返す出力

| ツール | 出力 |
|---|---|
| Claude Code | **何も出力しない**。`UserPromptSubmit` の標準出力はモデルの入力に入るため |
| Codex | `Stop` のみ `{}`。それ以外は無出力（`UserPromptSubmit` の出力は文脈になる） |
| Antigravity | すべてのフックが JSON を要求する。`Stop` は `{"decision":"allow"}`、他は `{}` |

フックは常に終了コード 0 で終わり、アプリが起動していなくても、失敗を表に出さない。

### 3.2 イベントの対応

| 入力 | `Kind` |
|---|---|
| `UserPromptSubmit` | `prompt` |
| `PreToolUse` `PostToolUse` | `activity` |
| `Notification` `PermissionRequest` | `attention` |
| `Stop` `StopFailure` `SessionEnd` | `finish` |
| `Interrupt`（Codex） | `interrupted` |
| Antigravity `SessionStart` `PreInvocation` | `start`（「送信」フックがないため、モデル呼び出しを作業の開始とみなす） |
| Antigravity `PostInvocation` `PostToolUse` | `activity` |
| Antigravity `Stop` | `fullyIdle == false` なら `background`、それ以外は `finish` |

---

## 4. 中断の検出

「止まった」ことは、ツールごとに別の方法で知る。沈黙の長さだけで推測しない。

| ツール | 方法 |
|---|---|
| Claude Code | (1) 監視対象プロセス（フックの親をたどって見つけた `claude`）が消えたら終了。(2) transcript（JSON Lines）の末尾に、`user` エントリの `[Request interrupted by user…]` が現れたら中断。assistant の出力や tool_result 内の同じ文字列は無視し、書きかけの行は判定しない |
| Codex | `Interrupt` フックで直接知る |
| Antigravity | 停止ボタンはフックも痕跡も残さない。**5 分間** 何も聞こえなければ終了とみなす（`quietTimeout`）。`Stop` が `fullyIdle: false` を返した（バックグラウンドの作業中）場合は対象外 |
| `remain run` | 実行中のコマンド自身の PID を監視する |

- **生存確認**: セッションがある間だけ、3 秒ごとに `checkLiveness()` が走る。PID の生存（`kill(pid, 0)`）と、transcript の追記部分のスキャンを行う。`scanOffset` は、最後に調べた完全な行の直後を指す。
- **PID の再利用対策**: Claude Code と Codex、Antigravity は、PID が生きているだけでなく、その実行ファイル名がツールのものと一致することも確認する（`remain run` は対象外）。調べられない場合は生きているとみなす。
- 新しい会話では最初のプロンプト時点で transcript がまだない。この場合は先頭（オフセット 0）から調べる。
- 中断・プロセス終了は「利用者がそこにいる」とみなし、通知も完了アクションも出さない。
- **安全網**: どのツールも、`sessionTimeout`（既定 1 時間）の間まったく反応がなければ、セッションを外す。Antigravity はこれと 5 分の小さいほうが適用される。

---

## 5. WakeEngine

### 5.1 設定 (`WakeSettings`)

UserDefaults のキー `wakeSettings` に JSON で保存する。キーの欠けた古い設定も、既定値で補って読める。

| 項目 | 既定 | 意味 |
|---|---|---|
| `sessionTimeout` | 1 時間 | 安全網（§4） |
| `holdWhileWaiting` | false | エージェントが入力待ちの間もスリープを防ぐ |
| `keepDisplayOn` | false | 防止中はディスプレイも消さない。すでに防止中のときだけ効く |
| `notifyOnFinish` / `notifyOnAttention` | true / true | 完了・入力待ちの通知 |
| `minimumNotifiableDuration` | 30 秒 | これより短い作業は通知しない |
| `completionAction` | nothing | 最後の作業が終わったあとの動作（何もしない／ディスプレイを消す／スリープ） |
| `batteryCutoffPercent` | 20 | これを下回ったらスリープを許可（0 = 無効） |
| `holdOnlyOnAC` | false | バッテリー駆動中は防がない |
| `respectLowPowerMode` | false | 低電力モード中は防がない |
| `releaseWhenOverheating` | true | 熱が `critical` のとき許可 |
| `keepRunningWithLidClosed` | false | ふた閉じモード |
| `lidClosedLimit` | 3 時間 | ふた閉じモードの上限（防止の開始から数える） |

古い版の `sessionTimeout = 15 分` は、読み込み時に 1 時間へ移行する。

### 5.2 防止するかの判断

```
wantsHold = (working なセッションがある)
          || 手動の防止がある (until / indefinite)
          || (holdWhileWaiting && waiting なセッションがある)

block     = 次のいずれか（上から評価）
            ・熱: ふた閉じ中かつふた閉じモード → `serious` 以上
                  それ以外 → releaseWhenOverheating かつ `critical`
            ・電池: ラッチ中（§6）
            ・低電力モード: respectLowPowerMode かつ有効
            ・バッテリー駆動: holdOnlyOnAC かつバッテリー駆動

防止レベル = wantsHold && block == nil
             ? (keepDisplayOn ? システム＋ディスプレイ : システム)
             : なし
```

`WakeSnapshot`（`prevention`、`workingCount`、`waitingCount`、`manual`、`blockedBy`、`preventLidSleep`）が UI と IPC に渡される。

### 5.3 手動の防止

`ManualMode` は `off` / `until(Date)` / `indefinite`。時間付きは期限に達すると `expire` が外す。手動の防止だけが動いている間に最後のセッションが終わっても、`allFinished` は出ない。

### 5.4 期限の管理

`nextDeadline()` が、セッションの沈黙期限・手動の期限・ふた閉じの上限のうち最も早い時刻を返し、コーディネーターがその時刻に 1 回だけ再計算する。常時のポーリングはしない。

---

## 6. 電源ガード

`SystemPowerMonitor` が、バッテリー残量・給電状態・低電力モード・熱の状態・ふたの開閉を `PowerState` として報告する。

- 購読: IOKit の電源変更（`IOPSNotificationCreateRunLoopSource`）、`thermalStateDidChangeNotification`、`NSProcessInfoPowerStateDidChange`。
- ふたの開閉（`IOPMrootDomain` の `AppleClamshellState`）には通知がないため、**ふた閉じモードがオンの間だけ** 3 秒ごとに調べる。
- ハンドラを付けた時点で現在の状態をただちに届ける（先に発生した変化を、重複排除で取りこぼさない）。
- **バッテリーのヒステリシス**: カットオフを下回るとラッチし、カットオフ + 5 ポイントに戻るまで解除しない（境界での出入りを防ぐ）。バッテリー駆動中だけ判定する。
- 防止中に止められたときは `holdSuspended(理由)` を通知する。条件が解消すれば自動で再開する。
- バッテリーのない Mac（`batteryPercent == nil`）では、バッテリーとふた閉じの設定を UI から隠す。

---

## 7. スリープ制御

- システムスリープ: `kIOPMAssertionTypePreventUserIdleSystemSleep`。ディスプレイ: `kIOPMAssertionTypePreventUserIdleDisplaySleep`。種類ごとに高々 1 つを保持し、不要になれば即座に解放する。
- 既定ではシステムスリープだけを防ぐ。エージェントに明るい画面は要らない。
- 完了アクションは `pmset displaysleepnow` / `pmset sleepnow`。最後の作業が終わって 10 秒の猶予のあと、その間に新しい作業や手動の防止が始まっていなければ実行する。作業が `minimumNotifiableDuration` より短かった場合は実行しない。

---

## 8. ふた閉じモード

ふたを閉じても動かし続けるには、システム全体のスリープを止める必要がある（`pmset disablesleep 1`）。これには root が必要で、鞄の中で眠らない Mac は危険でもある。**安全側に倒れること** を中心に作っている。

### 8.1 構成要素

| 要素 | 内容 |
|---|---|
| sudoers ルール | `/etc/sudoers.d/remain`。`<ユーザー> ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, /usr/bin/pmset disablesleep 1` の **この 2 つのコマンドだけ**。`visudo -cf` で検証してから `install -m 0440 -o root -g wheel` で配置する（壊れた sudoers で sudo を失わないため） |
| 見張り役 (watchdog) | LaunchAgent `dev.remain.lid-watchdog`。15 秒ごとに `lid-watchdog.sh` を実行し、ハートビートが 45 秒より古ければ `pmset disablesleep 0` を実行してファイルを消す |
| ハートビート | `~/Library/Application Support/remAIn/lid-heartbeat`。防止中、10 秒ごとに更新 |

- セットアップはパスワードを 1 度だけ求める（`osascript` の `with administrator privileges`）。**sudoers ルールと見張り役の両方が揃って初めて「準備完了」** とする（見張りなしの運用は安全網を外すことになるため）。
- ユーザー名は ASCII の英数字と `._-` のみ許可する。それ以外はセットアップを拒否する。

### 8.2 動作

- 防止の開始: ハートビートを先に書き、`pmset disablesleep 1` を実行して `SleepDisabled 1` になったことを確認する。失敗したらハートビートを消し、30 秒間は再試行しない（イベントごとに叩かず、通知も 5 分に 1 回まで）。
- 解除: `disablesleep 0` → ハートビートを消す。**ふたが閉じているなら `pmset sleepnow`** を実行する（他にスリープの引き金がないため）。
- ふたを閉じている間も画面が点いたままになる macOS の挙動への対策として、閉じた瞬間（または閉じた状態での防止開始時）に **1 回だけ** `pmset displaysleepnow` を実行する。
- 起動時の回復: ハートビートが残っていれば（前回の異常終了）スリープを戻す。ハートビートがないのに `disablesleep` が 1 なら、**利用者が自分で設定したものとして触れない**。
- 終了時（`willTerminate`）: 防止中なら解除する。
- 上限: `lidClosedLimit` に達すると `lidLimitReached` を通知し、以降のふた閉じ防止を外す（そのまま閉じればスリープする）。
- 熱が `serious` に達した場合、ふたが閉じていれば必ず止める（閉じた Mac は熱を逃がせないため、通常より厳しく見る）。

### 8.3 取り外し

設定の「削除」またはリセットで、見張り役（LaunchAgent とスクリプト）と sudoers ルールを削除する。パスワードのキャンセル時は、パスワード不要の見張り役の削除だけが行われる。

---

## 9. アクティビティログ

remAIn が Mac を起こしていた時間の記録。

```
HoldInterval { id, start, end, sources(agent|manual), projects(フォルダ名), agents, endReason }
```

- 保存先: `~/Library/Application Support/remAIn/activity.jsonl`（1 行 1 件の JSON Lines。壊れた行は 1 件を失うだけ）。**フルパスやプロンプトは保存しない**。保持期間は 90 日で、起動時に古い行を削除する。
- 実行中の区間は `activity-open.json` に保存し、60 秒ごと（と、元が増えたとき）に更新する。異常終了しても、最後の更新時刻で閉じて `appStopped` として回復する。1 秒未満の区間は記録しない。
- 終了理由: `finished` `interrupted` `processExited` `timedOut` `released` `timerElapsed` `powerGuard` `appQuit` `appStopped`。
- 集計は日をまたぐ区間を日ごとに分割する。区間に `agent` が含まれればその時間は「エージェント」、そうでなければ「手動」とする。プロジェクト別は、複数のプロジェクトにまたがる区間を等分する。
- 設定の「アクティビティ」タブ: 14 日のグラフ（縦軸は分／時間を 60 進の刻みで 15 分・30 分・1 時間…）、30 日と 7 日と今日の合計、プロジェクト別、最近の履歴。

---

## 10. IPC

- Unix ドメインソケット `~/Library/Application Support/remAIn/remain.sock`。ディレクトリは `0700`、ソケットは `0600`（自分のユーザーだけが接続できる）。
- 改行区切りの JSON。1 接続 1 リクエスト、1 レスポンス。読み書きのタイムアウトは 1 秒、1 メッセージの上限は 1 MiB。
- リクエスト: `event(AgentEvent)` / `status` / `sessions` / `keepAwake(minutes)` / `release`。レスポンス: `{ ok, message?, snapshot? }`。
- フックの失敗（アプリ未起動など）は、フックを呼んだツールの動作に影響させない。

---

## 11. CLI (`remain`)

| コマンド | 内容 |
|---|---|
| `hook [claude\|codex\|antigravity <Event>]` | フックの受け口（引数なしは Claude Code。古いインストール用） |
| `status` `sessions` | 現在の状態、追跡中のセッションの一覧 |
| `on [分]` `off` | 手動の防止（無期限、または N 分）／解除 |
| `run [--] <コマンド>` | コマンドの間だけ防ぐ。終了コードを引き継ぐ。30 秒ごとに `activity` を送る |
| `install-hooks [agent]` `uninstall-hooks [agent]` | 連携の書き込み／削除 |
| `doctor` | アプリの稼働、各ツールの連携、ふた閉じの準備、デバッグログを一覧する |
| `reset`（別名 `uninstall`） | フック、ふた閉じの設定、データを削除する |
| `debug [on\|off]` | フックの生の呼び出しをログに記録する（診断用。既定はオフ。Claude/Codex はイベント名のみ） |
| `version` | バージョン |

`hook` は `os_log`（サブシステム `dev.remain.cli`）に、配信の成否だけを残す。ペイロードは記録しない。

---

## 12. UI

### 12.1 メニューバーのアイコン

SF Symbols。幅の違いで位置がずれないよう、22pt の固定幅に中央揃えで置く。

| 状態 | シンボル |
|---|---|
| エージェントが作業中 | `sparkles` |
| 手動の防止中、または防止中 | `cup.and.saucer.fill` |
| 入力待ち（防止していない） | `hourglass` |
| 待機中 | `moon.zzz` |
| 電池・熱で止めている | `battery.25percent` / `battery.50percent` / `thermometer.high` |

VoiceOver には `remAIn: <状態>` を読ませる。

### 12.2 メニュー（`MenuBarExtra` の `.menu` スタイル、実体は NSMenu）

1. 状態の行（「通常どおりスリープします」「エージェントが作業中」「9:33までスリープを防止中（残り45分）」「スリープを許可中: 理由」など）。手動の防止だけの状態では、押すと解除される。それ以外は押しても何も起きない（無効表示の薄い灰色を避けるため、ボタンとして置く）
2. 必要なときだけ: 「エージェントの設定を完了…」（連携が壊れているとき、または連携が 1 つもないとき。利用者が意図してオフにしたツールでは出さない）、エージェントの作業中に手動の防止が重なっているときの「手動: …」行
3. 「スリープを防ぐ」サブメニュー: オフ／30 分／1 時間／2 時間／4 時間／無期限（チェックが現在の選択）
4. 「蓋を閉じても動作を続ける」（バッテリーのある Mac のみ。準備前に押すと設定へ案内する）
5. 「設定…」「remAInについて」「remAInを終了」

### 12.3 設定ウインドウ

固定サイズ（460×620）。内容が長いタブはフォーム内でスクロールする。

- **一般**: エージェント／エージェントの完了時／電源／蓋を閉じたとき／連携／ログイン時に開く／設定をリセット。頻繁に変える順に並べ、連携は初回設定で済むので下に置く。連携はアルファベット順（Antigravity、Claude Code、Codex）。
- **アクティビティ**: §9。

### 12.4 ウェルカム画面

初回起動時のみ（リセット後は再び出る）。見つかったツールの連携トグルと、「ログイン時に開く」（既定オン）を出す。閉じたときに、通知の許可を求め、ログイン項目の選択を反映する。

### 12.5 その他

- Dock に出ない（`LSUIElement`、起動時に `.accessory`）。アプリを再度開くと設定が開く（メニューバーのアイコンが、ノッチや混雑で隠れても戻れるように）。
- 「remAInについて」は標準の About パネル。名前、アイコン、バージョン（ビルド番号つき）、リポジトリへのリンク、著作権。
- 日本語と英語。英語がソース言語で、`Resources/ja.lproj/Localizable.strings` に日本語の訳を持つ。ビルド時にバンドルへコピーする。
- アプリのアイコンは `scripts/make-icon.swift` で CoreGraphics により描画（SF Symbols はアイコンへの使用がライセンス上禁止のため使わない）。

---

## 13. 通知と完了アクション

- 通知は `UNUserNotificationCenter`。アプリがバンドル外（`swift run`）のときは何もしない。許可は、ウェルカム画面を閉じたとき、または設定で通知をオンにしたときに求める。システム設定で拒否されている場合は、設定画面に案内とボタンを出す。
- 種類: 完了（`minimumNotifiableDuration` 以上のとき）、入力待ち、防止を止めた理由、ふた閉じの上限到達、ふた閉じの失敗。
- 完了アクション（§7）は通知とは別に、`allFinished` でスケジュールされる。

---

## 14. リセットとアンインストール

設定の「設定をリセット…」（確認ダイアログあり）または `remain reset`。各ステップは独立していて、1 つが失敗しても、残りは実行される。

1. 各ツールの remAIn のフックを削除（読み取れない設定ファイルは触らず、報告する）
2. ふた閉じ: スリープを戻し、sudoers ルールと見張り役を削除
3. データ: `activity.jsonl` `activity-open.json` `hook-debug.jsonl` `debug` `lid-heartbeat` `lid-watchdog.sh`
4. （アプリのみ）ログイン項目の解除、保存済みの設定と初回起動の記録を削除、実行中の設定を既定へ戻す

アプリ本体は残る。削除はゴミ箱へ移すだけでよい。

---

## 15. ビルドと配布

- `scripts/build-app.sh`: arm64 と x86_64 を別々にビルドして `lipo` で結合（Xcode なしで動く）。`build/remAIn.app` に Info.plist、ローカライズ、アイコン、`Contents/Helpers/remain` を置き、ad-hoc 署名する。
- バージョンは `Sources/RemainCore/Version.swift` の `remainVersion` が唯一の出所。ビルド番号は CI の実行番号、なければコミット数。
- **署名・公証なし**（Apple Developer Program に未加入）。初回は Gatekeeper の警告が出るため、「システム設定 → プライバシーとセキュリティ → このまま開く」が必要。
- CI（`.github/workflows/ci.yml`）: `swift build` と `swift test`。
- リリース（`release.yml`）: `v*` タグで起動。タグと `remainVersion` の一致を確認 → テスト → ビルド → `ditto` で zip 化 → GitHub Release を作成。
- GitHub Pages（`pages.yml`）: `docs/` を公開する。

---

## 16. 保存されるデータ

| 場所 | 内容 |
|---|---|
| UserDefaults（`dev.remain.app`） | 設定、初回起動済みの記録、ふた閉じの注意に同意した記録 |
| `~/Library/Application Support/remAIn/` | `remain.sock`、`activity.jsonl`、`activity-open.json`、`lid-heartbeat`、`lid-watchdog.sh`、（診断オン時）`hook-debug.jsonl` と `debug` |
| `~/Library/LaunchAgents/dev.remain.lid-watchdog.plist` | ふた閉じの見張り役（セットアップ時のみ） |
| `/etc/sudoers.d/remain` | ふた閉じの sudo ルール（セットアップ時のみ） |
| 各ツールの設定ファイル | remAIn のフック（§3）。初回書き込み時のバックアップ `*.remain-backup` |

外部への通信は行わない。履歴にはフォルダ名のみを保存し、フルパスやプロンプトは保存しない。

---

## 17. テスト

Swift Testing で 191 件。エンジン、コーディネーター、連携のインストーラー、フックのデコード、生存確認と transcript のスキャン、電源ガード、ふた閉じ（コントローラー、見張り役、セットアップ）、アクティビティ、リセットをカバーする。

- 時刻、OS への反映、電源、ふたの状態、`pmset` はすべて差し替え可能（`FakeAssertions` `FakeProbe` `FakeDisabler` `TestClock` など）。実機の電源や設定には触れない。
- Command Line Tools だけの環境では、Testing のフレームワークパスを渡す必要がある（README 参照）。`Testing` と `Foundation` を同じファイルでインポートしないため、Foundation を使うヘルパーは `Support.swift` に集めている。
