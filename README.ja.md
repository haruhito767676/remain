<div align="center">

<img src="docs/media/icon-256.png" width="112" alt="remAIn">

# remAIn

AIコーディングエージェントが働いている間だけ、Macを起こしておく。

Claude Code、Codex、Antigravityを見守る、小さなmacOSのメニューバーアプリです。<br>
エージェントが働いている間は、Macを起こしたまま。止まったら、いつもどおりスリープします。

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-0a84ff)](#インストール)
[![Release](https://img.shields.io/github/v/release/haruhito767676/remain?color=0a84ff)](https://github.com/haruhito767676/remain/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#ライセンス)

[ダウンロード](https://github.com/haruhito767676/remain/releases/latest) · [English](README.md) · [技術仕様書](SPEC.md)

<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/media/shot-menu-submenu-dark-ja.webp">
  <img src="docs/media/shot-menu-submenu-light-ja.webp" width="430" alt="remAInのメニュー。状態の行、30分から無期限までを選べる「スリープを防ぐ」のサブメニュー、蓋を閉じても動作を続けるスイッチ">
</picture>

</div>

<!-- デモ動画は、できたらここに入れます。 -->

---

## なぜ

長いエージェントの作業は、Macがスリープすると途切れてしまいます。「スリープを防ぐ」スイッチを入れれば解決しますが、作業が終わったあとも、Macは起きたままです。切るのも、自分で覚えておかなければなりません。remAInはエージェントを見守るので、Macが起きているのは、エージェントが働いている間だけです。

## できること

### 働いている間だけ起こし、それ以外は眠らせる

<table>
<tr>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/media/shot-menu-idle-dark-ja.webp">
  <img src="docs/media/shot-menu-idle-light-ja.webp" width="290" alt="待機中。メニューには「通常どおりスリープします」と出ます">
</picture>
<br><sub>何も動いていないとき: いつもどおり、スリープします。</sub>
</td>
<td align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/media/shot-menu-working-dark-ja.webp">
  <img src="docs/media/shot-menu-working-light-ja.webp" width="290" alt="エージェントの作業中。メニューにそう出て、Macは起きたままです">
</picture>
<br><sub>エージェントが作業中: Macは起きたままです。</sub>
</td>
</tr>
</table>

Claude Code、Codex、Antigravityを各ツールのフックでつなぎ、セッションが始まった、作業している、入力を待っている、終わった、を把握します。複数のセッションが同時に動いても大丈夫です。Escキーでの中断や、ツールを閉じたことも検知するので、中断したエージェントのせいでMacが眠れなくなることはありません。それ以外のものは、`remain run -- <コマンド>` で見守れます。

### 手動でスリープを防ぐ

メニューから、30分、1時間、2時間、4時間、または無期限で防げます。残り時間はメニューに出て、押すと解除できます。

### 蓋を閉じても、動かし続ける

蓋を閉じても、エージェントは動き続けます。作業が終わると、Macはスリープします。最初に一度だけ、パスワードが必要です。安全側に倒れるように作ってあり、remAIn自体が落ちても、見張り役が通常のスリープに戻します。高温、バッテリー低下、上限時間(既定は3時間)でも、自動的に止まります。初期状態ではオフです。

### バッテリーと熱の保護

バッテリー残量が少ないとき、バッテリー駆動のとき、低電力モードのとき、高温のときは、Macのスリープを許可し、その理由をお知らせします。条件が解消すれば、自動で再開します。

### 通知と完了時の動作

作業の完了や、入力待ちをお知らせします。すべて終わったあとに、ディスプレイを消す、Macをスリープさせる、も選べます。

### アクティビティ

Macを起こしていた時間を、日ごと、プロジェクトごとに確認できます。記録はこのMacの中だけに保存され、90日で削除されます。

<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/media/shot-settings-activity-dark-ja.webp">
  <img src="docs/media/shot-settings-activity-light-ja.webp" width="400" alt="「アクティビティ」タブ。今日、過去7日間、30日間、14日間のグラフ、プロジェクト別の時間">
</picture>
</p>

---

## インストール

1. [Releases](https://github.com/haruhito767676/remain/releases/latest) から `remAIn-v1.0.0.zip` をダウンロードして展開し、remAInをアプリケーションフォルダへ移動します。
2. remAInは個人開発の無料アプリで、Appleの署名を受けていません。そのため、初回はmacOSが警告を出します。「システム設定」→「プライバシーとセキュリティ」を開いて、下へスクロールし、「このまま開く」を選んで、Touch IDかパスワードで確認してください。一度行えば、次回からは普通に起動できます。
3. ウェルカム画面で、見つかったツールとの連携を選べます。あとから「設定」→「連携」で変えられます。

<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/media/shot-welcome-dark-ja.webp">
  <img src="docs/media/shot-welcome-light-ja.webp" width="400" alt="ウェルカム画面。ツールごとのスイッチと「ログイン時にremAInを開く」">
</picture>
</p>

動作環境: macOS 14以降。

## 対応ツール

| ツール | 見守り方 |
| --- | --- |
| Antigravity | `~/.gemini/config/hooks.json` のフック。停止ボタンはフックも痕跡も残さないため、5分間なにも聞こえなければ終了とみなします(バックグラウンドのコマンドが動いていると伝えてきた場合を除く)。 |
| Claude Code | `~/.claude/settings.json` のフック(CLI、デスクトップアプリ、VS Code拡張)。Escキーでの中断や、ツールを閉じたことを検知します。 |
| Codex | `~/.codex/hooks.json` のフック(CLIとデスクトップアプリ)。Codexは最初に、フックの確認と信頼を求めます。また、フックは会話の作業フォルダで起動されるため、そのフォルダが存在しないと(デスクトップアプリの仮の「New project」など)、すべてのフックが `No such file or directory` で失敗します。実在するフォルダを開いてください。 |
| それ以外 | `remain run -- <コマンド>` で、そのコマンドが動いている間、起こしておきます。 |

既存の設定は壊しません。remAInが追加・削除するのは、自分の項目だけで、書き換える前に、初回だけバックアップを隣に残します(例: `settings.json.remain-backup`)。アプリを移動しても、起動時に、フックの向き先を自動で直します。`remain doctor` で、つながっているもの、いないものを確認できます。

<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/media/shot-settings-bottom-dark-ja.webp">
  <img src="docs/media/shot-settings-bottom-light-ja.webp" width="400" alt="設定の下半分。蓋を閉じたとき、連携、ログイン時に開く、設定のリセット">
</picture>
</p>

## プライバシー

remAInはインターネットに接続しません。アカウントも、アクセス解析も、外部のライブラリもありません。アプリ、`remain` コマンド、フックは、自分のユーザーだけが開けるUnixソケットで会話します。履歴に残るのは、プロジェクトのフォルダ名だけで、フルパスやプロンプトは保存せず、90日で削除されます。アプリの中にあるリンクは、「remAInについて」のリポジトリへのリンクだけで、押したときにしか開きません。

## リセットとアンインストール

「設定」→「設定をリセット…」(ターミナルなら `remain reset`)で、remAInがMacに追加したものをすべて取り除き、初回起動の状態に戻せます。各ツールの設定ファイルにある、remAInの項目(あなたの項目はそのまま)、蓋を閉じたときの許可と見張り役(macOSがパスワードを求めます)、ログイン項目、保存した設定と履歴です。アンインストールするときは、リセットしてからremAInを終了し、アプリをゴミ箱へ移してください。

## CLI

```sh
remain status
remain on [分]           # 手動でスリープを防ぐ
remain off
remain run -- <コマンド>  # コマンドが動いている間だけ防ぐ(ビルド、ダウンロード、ほかのエージェント)
remain doctor            # つながっているもの、いないものを確認
remain install-hooks     # 「設定」→「連携」でツールをオンにするのと同じ
```

<details>
<summary>設定の詳細</summary>

<br>

- 連携: それぞれのスイッチが、そのツールの設定に、remAInのフックを書き込む、または取り除きます。フックが別のremAInを指しているツールには「修復が必要」と出ます(起動時に自動でも直ります)。
- 反応がなくなってから解除するまで: 安全網です。エージェントの中断や終了は、それとは別に検知します。ほかの理由で静かになったセッションにだけ、効きます。Antigravityには、5分の専用の決まりがあります。
- スリープを防ぐ間は、ディスプレイも消さない: すでに防いでいる間(エージェントが作業中、または手動)を延ばすだけで、これだけでは何もしません。蓋を閉じているときは、ディスプレイは必ず消します。
- 電源: 上限(バッテリー残量のしきい値、バッテリー駆動、低電力モード、高温)で止めたときは、Macのスリープを許可して理由をお知らせし、条件が解消したら自動で再開します。バッテリーの上限は、ばたつかないよう、しきい値より5ポイント上がるまで再開しません。
- すべての作業が終わったら: 選んだ動作(ディスプレイを消す、スリープ)は、最後の作業が終わって10秒後に実行します。その間に新しい作業を始めたときや、作業が「所要時間がこれ以上の作業のみ」より短かったときは、実行しません。
- バッテリーと蓋の設定は、バッテリーのないMacでは隠れます。
- 蓋を閉じたとき: 設定には、最初に一度だけパスワードが必要です。`pmset disablesleep 0|1` だけを許可する狭い `sudoers` のルール(先に `visudo` で検証します)と、remAInが心拍の更新を止めたらスリープを戻す、launchdの見張り役を追加します。また、実際に役立てるにはネットワーク接続が必要です(移動中はテザリングなどで)。

</details>

<details>
<summary>しくみ</summary>

<br>

```
Claude Code ──フック (標準入力にJSON)──▶ remain hook ──Unixソケット──▶ remAIn.app
                                                                         │
                                          WakeEngine (純粋な状態機械)
                                                                         │
                                                 IOPMAssertion (システムスリープ)
```

各ツールのフックのイベントを、少数の信号(セッションが始まった、作業している、待っている、終わった、中断された)にそろえ、純粋な状態機械が、Macを起こしておくかどうかを決めます。中断の検知はツールごとに違います。Claude Codeはプロセスとtranscript、CodexはInterruptフック、Antigravityは沈黙のタイムアウトです。仕様の全体(構成、イベントモデル、ふた閉じの安全対策、データファイル)は、[SPEC.md](SPEC.md) にあります。

</details>

<details>
<summary>ソースからビルドする</summary>

<br>

```sh
./scripts/build-app.sh
open build/remAIn.app
```

アプリはad-hoc署名です。開発するときは、次のとおりです。

```sh
swift build
swift test
```

macOS 14以降とSwift 6が必要です。Command Line Toolsだけの環境で `swift test` が `no such module 'Testing'` で失敗するときは、Xcodeを入れるか、フレームワークのパスを渡してください。

```sh
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
swift test -Xswiftc -F$F -Xlinker -F$F -Xlinker -rpath -Xlinker $F
```

スクリーンショットは、実際の履歴に触れずに作り直せます。`scripts/make-demo-data.swift` がサンプルの履歴を書き出し、環境変数 `REMAIN_SUPPORT_DIR` で、アプリをそこへ向けます。`promo/process-shots.sh` が、撮ったままの画像を、ここで使うファイルに整えます。

バージョンは、`Sources/RemainCore/Version.swift` の1か所にあります。リリースするときは、これを上げてコミットし、`v<バージョン>` のタグを付けてください。`.github/workflows/release.yml` が、テスト、ビルドを行い、`docs/release/v<バージョン>.md` をリリースノートにして、`remAIn-v<バージョン>.zip` をGitHubのリリースに添えます。

アプリのアイコンは、コード(`scripts/make-icon.swift`、CoreGraphicsのみ)で描き、`Resources/AppIcon.icns` として置いています。

</details>

## ライセンス

MIT
