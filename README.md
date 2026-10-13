# remAIn

A tiny macOS menu bar app that keeps your Mac awake **only while an AI coding agent is actually working**.

Long agent runs (Claude Code, etc.) get killed when the Mac idles to sleep. A plain "stay awake" toggle fixes that, but leaves the Mac awake long after the agent has finished. remAIn listens to Claude Code's [hooks](https://code.claude.com/docs/en/hooks) and holds a sleep assertion for exactly as long as the agent is busy.

## How it works

```
Claude Code ──hook (JSON on stdin)──▶ remain hook ──Unix socket──▶ remAIn.app
                                                                      │
                                         WakeEngine (pure state machine)
                                                                      │
                                              IOPMAssertion (system sleep)
```

| Claude Code event | remAIn |
| --- | --- |
| `UserPromptSubmit` | session starts → stay awake |
| `PreToolUse` / `PostToolUse` | heartbeat; resumes after a permission prompt |
| `Notification` | agent waits for you → allow sleep (configurable) |
| `Stop` / `StopFailure` / `SessionEnd` | session ends → release |

Design notes:

- **Display may sleep.** Agents don't need a lit screen, so by default only *system* sleep is prevented.
- **Sessions are tracked per `session_id`**, so several parallel sessions work.
- **Interruptions don't pin your Mac awake.** Claude Code fires no `Stop` hook when you press Esc or reject a tool, so remAIn watches two things instead of guessing from silence:
  - the Claude Code *process* (found by walking up from the hook process): if it exits or crashes, the session ends;
  - the session *transcript*: a user-role `[Request interrupted by user…]` entry ends the session. Only user entries count, so the same text in assistant output or tool results is ignored, and half-written lines are never judged.
  A long silence timeout (1 hour by default) remains as a last-resort safety net.
- **Late hooks are ignored** for sessions that already finished, so reordering can't resurrect them.
- **The hook command never prints and always exits 0**, so it can't pollute the model's context or break Claude Code if the app isn't running.
- The core logic (`WakeEngine`) is a pure value type with injected time and is fully unit-tested. IOKit sits behind a protocol.

When agents finish, remAIn can also:

- **Notify you** when a task finishes or needs your input (tasks shorter than a configurable length stay quiet).
- **Run an action** once the *last* agent is done — turn the display off or sleep the Mac — after a 10 second grace period that is cancelled if you start new work.

**Power guard.** A stay-awake tool should not drain a laptop in a bag. remAIn lets the Mac sleep when the battery falls to a threshold (20% by default, with 5 points of hysteresis so it doesn't flap), and optionally when running on battery at all, in Low Power Mode, or when macOS reports a critical thermal state. It resumes by itself once the condition clears, and tells you when it steps aside.

**Lid-closed mode (opt-in).** For the commute: keep an agent running while the MacBook is closed in a bag. macOS only allows that with `pmset disablesleep`, which needs root, and a Mac that never sleeps in a bag is a hazard, so this is built to fail safe:

- one-time admin approval installs a `sudoers` rule for exactly `pmset disablesleep 0` and `pmset disablesleep 1` (validated with `visudo` first);
- while active, remAIn refreshes a heartbeat file; a launchd **watchdog** turns sleep back on if it goes stale (crash, `kill -9`), and the app repairs any leftover state on launch;
- when the lid closes during a hold, remAIn turns the display off itself (`pmset displaysleepnow`): macOS otherwise keeps treating the display as on and only logs "Display is turned off" once the hold ends;
- it only holds while an agent works, then lets the Mac sleep (immediately if the lid is closed);
- stricter limits while closed: heat (`serious`), battery, and a time limit (3 h default).

It needs a network connection to be useful (tether on the move). Off by default; the first activation shows a warning.

**Activity log.** Every stretch of time remAIn kept the Mac awake is recorded: start, end, agent or manual, the project folder name and why it ended (finished, interrupted, Claude Code closed, timer, power guard, ...). The menu shows today's total and Settings → Activity shows a 14-day chart, per-project totals and recent history. Data lives in `~/Library/Application Support/remAIn/activity.jsonl` (JSON Lines, 90 days, never leaves the Mac, folder names only). The running interval is checkpointed every minute, so a crash loses at most a minute.

The UI is localized (English, 日本語) and follows the system language. Translations live in `Resources/<lang>.lproj/Localizable.strings`; English strings in the code are the keys.

Works with the Claude Code CLI, desktop app and the VS Code extension, since all read the same `~/.claude/settings.json`.

## Supported tools

| Tool | How it is followed |
| --- | --- |
| Claude Code | hooks in `~/.claude/settings.json` (CLI, desktop, VS Code extension) |
| Antigravity | hooks in `~/.gemini/config/hooks.json`; model calls count as work. Its stop button fires no hook and leaves no trace in its log, so a run that goes quiet for 5 minutes is considered over, unless `Stop` said a background command is still running (`fullyIdle: false`) |
| Codex | hooks in `~/.codex/hooks.json` (CLI and desktop app). Codex asks you to review and trust them first, and starts hooks in the conversation's working folder: if that folder does not exist (the desktop app's placeholder "New project"), every hook fails with `No such file or directory`, so open a real folder. Checked: prompt, stop and interrupt (Esc). Not exercised yet: tool-use and approval events |
| anything else | `remain run -- <command>` holds while the command runs |

Settings → Integrations (and a welcome window on first launch) connects the tools it finds. If the app is moved, the hooks it wrote are re-pointed automatically at launch. `remain doctor` shows what is connected and what is not; `remain debug on` records raw hook calls (field names only for Claude Code and Codex, since their payloads contain your prompts).

## Privacy

remAIn never connects to the internet and has no third-party dependencies. The app, the `remain` command and the hooks talk to each other over a Unix socket that only your user can open. Everything it stores (activity history, settings) stays on your Mac: history keeps project folder names, never full paths or prompts, and expires after 90 days. The only link in the app is the repository link in About, which opens only if you click it.

## Reset and uninstall

Settings → General → **Reset Settings…** (or `remain reset` in a terminal) takes back everything remAIn put on the Mac and returns it to its first-launch state:

- its own entries in each tool's hooks file (yours are left alone; a file that cannot be parsed is never rewritten);
- the lid-closed `sudoers` rule and watchdog (sleep is switched back on first; macOS asks for your password);
- the login item, saved settings and activity history.

To uninstall, reset, quit remAIn and move the app to the Trash.

## Settings in detail

The settings explain themselves; the details are here.

- **Release automatically after no activity for**: a safety net. Interruptions and exits of an agent are detected on their own; this only matters for a session that goes quiet for any other reason. Antigravity has its own 5-minute rule (see above).
- **Keep the display on while preventing sleep**: only extends a hold that is already active (an agent working, or Keep Awake); on its own it does nothing. With the lid closed the display is always switched off.
- **Power**: when a limit stops the hold (battery below the threshold, battery power, Low Power Mode, heat), remAIn lets the Mac sleep and tells you why, and resumes by itself once the condition clears. The battery limit resumes 5 points above the threshold so it does not flap.
- **When all tasks are done**: the chosen action (turn the display off, sleep) runs 10 seconds after the last task ends and is skipped if you start new work or if the work was shorter than "Only for work that took longer than".
- **Lid closed**: needs your password once to set up; see above for how it fails safe.

## Install

```sh
./scripts/build-app.sh
open build/remAIn.app
```

The app is ad-hoc signed; on first launch use right-click → Open. Then open **Settings… → Claude Code → Install** to register the hooks (existing settings are preserved, a one-time backup is written to `settings.json.remain-backup`).

## CLI

```sh
remain status
remain on [minutes]    # manual hold
remain off
remain run -- <command>  # hold while any command runs (builds, downloads, other agents)
remain install-hooks   # same as the Settings button
```

## App icon

The icon is drawn in code (`scripts/make-icon.swift`, plain CoreGraphics, no SF Symbols since Apple's license forbids them in app icons) and committed as `Resources/AppIcon.icns`. A sleeping moon sits inside a task-progress ring whose bright head carries an AI sparkle: stay awake while the task runs. Regenerate with `swift scripts/make-icon.swift`.

## Development

```sh
swift build
swift test
```

Requires macOS 14+ and Swift 6. If `swift test` fails with `no such module 'Testing'` on a Command Line Tools–only setup, install Xcode or pass the framework path:

```sh
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
swift test -Xswiftc -F$F -Xlinker -F$F -Xlinker -rpath -Xlinker $F
```

## Releases

The version lives in one place, `Sources/RemainCore/Version.swift`. To release: bump it, commit, then tag `v<version>`.

Pushing a tag like `v0.2.0` runs `.github/workflows/release.yml`, which tests, builds the app and attaches `remAIn-v0.2.0.zip` to a GitHub release. The landing page in `docs/` is deployed with GitHub Pages (set *Settings → Pages → Source* to *GitHub Actions* once).

## License

MIT
