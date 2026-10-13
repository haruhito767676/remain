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

The UI is localized (English, 日本語) and follows the system language. Translations live in `Resources/<lang>.lproj/Localizable.strings`; English strings in the code are the keys.

Works with the Claude Code CLI, desktop app and the VS Code extension, since all read the same `~/.claude/settings.json`.

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

Pushing a tag like `v0.2.0` runs `.github/workflows/release.yml`, which tests, builds the app and attaches `remAIn-v0.2.0.zip` to a GitHub release. The landing page in `docs/` is deployed with GitHub Pages (set *Settings → Pages → Source* to *GitHub Actions* once).

## License

MIT
