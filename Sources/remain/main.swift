import Foundation
import RemainCore

// `remain hook` is invoked by Claude Code. It must never fail loudly or print anything:
// stdout of some hook events is fed back into the model's context.

func executablePath() -> String {
    let arg0 = CommandLine.arguments[0]
    let url = arg0.hasPrefix("/")
        ? URL(fileURLWithPath: arg0)
        : URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(arg0)
    return url.standardizedFileURL.resolvingSymlinksInPath().path
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func request(_ req: IPCRequest) -> IPCResponse {
    do {
        return try IPCClient.send(req)
    } catch {
        fail("remAIn is not running (\(error)).")
    }
}

func describe(_ snapshot: WakeSnapshot) -> String {
    var parts: [String] = []
    switch snapshot.manual {
    case .off: break
    case .indefinite: parts.append("manual: on")
    case .until(let date): parts.append("manual: until \(date.formatted(date: .omitted, time: .shortened))")
    }
    parts.append("agents working: \(snapshot.workingCount)")
    parts.append("waiting: \(snapshot.waitingCount)")
    let state = snapshot.prevention == .none ? "sleep allowed" : "keeping awake"
    return "\(state) (" + parts.joined(separator: ", ") + ")"
}

/// Runs a command and keeps the Mac awake for exactly as long as it runs. Works with any tool,
/// including agents that have no hooks. The command's own process is what remAIn watches, so even
/// if this wrapper is killed the app notices when the command is gone.
func runCommand(_ command: [String]) -> Never {
    guard !command.isEmpty else {
        fail("usage: remain run [--] <command> [arguments…]")
    }
    let session = "run-\(UUID().uuidString.prefix(8))"
    let directory = FileManager.default.currentDirectoryPath

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env") // resolves the command through PATH
    process.arguments = command
    do {
        try process.run()
    } catch {
        fail("cannot run \(command[0]): \(error)")
    }
    // The terminal sends Ctrl-C to the whole foreground group. Let the command handle it and keep
    // this wrapper alive to report the end. Set after spawning, because "ignore" is inherited by exec.
    signal(SIGINT, SIG_IGN)

    func report(_ event: String) {
        var payload = HookPayload(sessionID: session, eventName: event, cwd: directory)
        payload.claudePID = process.processIdentifier // the command itself: if it dies, the hold ends
        _ = try? IPCClient.send(.hook(payload))
    }
    report("UserPromptSubmit")
    var lastBeat = Date()
    while process.isRunning {
        Thread.sleep(forTimeInterval: 0.25)
        // A long silent command must not hit the silence timeout.
        if Date().timeIntervalSince(lastBeat) >= 30 {
            report("PostToolUse")
            lastBeat = Date()
        }
    }
    report("Stop")
    exit(process.terminationReason == .uncaughtSignal ? 128 + process.terminationStatus : process.terminationStatus)
}

let usage = """
usage: remain <command>
  status                 show the current state
  sessions               list tracked agent sessions (debugging)
  run [--] <command>     keep the Mac awake while a command runs
  on [minutes]           keep the Mac awake (indefinitely, or for N minutes)
  off                    release the manual hold
  install-hooks          register remAIn with Claude Code
  uninstall-hooks        remove remAIn from Claude Code
"""

let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "hook":
    let input = FileHandle.standardInput.readDataToEndOfFile()
    if var payload = try? JSONDecoder().decode(HookPayload.self, from: input) {
        // Tell the app which process to watch and where to look for interruptions.
        payload.claudePID = ProcessTree.claudeAncestor()
        payload.transcriptSize = payload.transcriptPath.flatMap { TranscriptScanner.fileSize(atPath: $0) }
        _ = try? IPCClient.send(.hook(payload))
    }
    exit(0)
case "status":
    let response = request(.status)
    print(response.snapshot.map(describe) ?? "unknown")
case "run":
    runCommand(Array(args.dropFirst().drop(while: { $0 == "--" })))
case "sessions":
    print(request(.sessions).message ?? "unknown")
case "on":
    let minutes = args.dropFirst().first.flatMap { Int($0) }
    let response = request(.keepAwake(minutes: minutes))
    print(response.snapshot.map(describe) ?? "ok")
case "off":
    let response = request(.release)
    print(response.snapshot.map(describe) ?? "ok")
case "install-hooks", "uninstall-hooks":
    let installer = HookInstaller(executablePath: executablePath())
    do {
        if args[0] == "install-hooks" {
            try installer.install()
            print("Installed remAIn hooks in \(installer.settingsURL.path)")
        } else {
            try installer.uninstall()
            print("Removed remAIn hooks from \(installer.settingsURL.path)")
        }
    } catch {
        fail("\(error)")
    }
default:
    print(usage)
    exit(args.isEmpty || args.first == "help" ? 0 : 1)
}
