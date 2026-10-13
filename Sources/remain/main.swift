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

    func report(_ kind: AgentEvent.Kind) {
        let event = AgentEvent(sessionID: session, cwd: directory, kind: kind, pid: process.processIdentifier, agent: .command)
        _ = try? IPCClient.send(.event(event)) // pid = the command itself: if it dies, the hold ends
    }
    report(.prompt)
    var lastBeat = Date()
    while process.isRunning {
        Thread.sleep(forTimeInterval: 0.25)
        // A long silent command must not hit the silence timeout.
        if Date().timeIntervalSince(lastBeat) >= 30 {
            report(.activity)
            lastBeat = Date()
        }
    }
    report(.finish)
    exit(process.terminationReason == .uncaughtSignal ? 128 + process.terminationStatus : process.terminationStatus)
}

let usage = """
usage: remain <command>
  status                 show the current state
  sessions               list tracked agent sessions (debugging)
  run [--] <command>     keep the Mac awake while a command runs
  on [minutes]           keep the Mac awake (indefinitely, or for N minutes)
  off                    release the manual hold
  install-hooks [agent]  register remAIn with claude (default) or antigravity
  uninstall-hooks [agent] remove remAIn from that tool
  debug [on|off]         record raw hook calls to a log (diagnostics)
"""

let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "hook":
    // remain hook [claude|codex|antigravity <Event>]   (no argument = Claude Code, for older installs)
    let agent = args.dropFirst().first.flatMap { AgentKind(cliName: $0) } ?? .claudeCode
    let eventArgument = args.dropFirst(2).first
    let input = FileHandle.standardInput.readDataToEndOfFile()
    var decoded = HookDecoder.decode(agent: agent, eventName: eventArgument, stdin: input)
    if var event = decoded {
        // Tell the app which process to watch and where to look for interruptions.
        event.pid = ProcessTree.agentAncestor(for: agent)
        if let path = event.transcriptPath { event.transcriptSize = TranscriptScanner.fileSize(atPath: path) }
        decoded = event
        _ = try? IPCClient.send(.event(event))
    }
    HookDebugLog.record(agent: agent, eventArgument: eventArgument, stdin: input, decoded: decoded, processes: ProcessTree.ancestors())
    // Some tools want JSON back; Claude Code must get nothing (its stdout reaches the model).
    if let response = HookDecoder.response(agent: agent, eventName: eventArgument) { print(response) }
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
    let agent = args.dropFirst().first.flatMap { AgentKind(cliName: $0) } ?? .claudeCode
    let install = args[0] == "install-hooks"
    do {
        switch agent {
        case .claudeCode:
            let installer = HookInstaller(executablePath: executablePath())
            if install { try installer.install() } else { try installer.uninstall() }
            print("\(install ? "Installed remAIn hooks in" : "Removed remAIn hooks from") \(installer.settingsURL.path)")
        case .antigravity:
            let installer = AntigravityHookInstaller(executablePath: executablePath())
            if install { try installer.install() } else { try installer.uninstall() }
            print("\(install ? "Installed remAIn hooks in" : "Removed remAIn hooks from") \(installer.configURL.path)")
        case .codex, .command:
            fail("\(agent.displayName) is not supported yet.")
        }
    } catch {
        fail("\(error)")
    }
case "debug":
    switch args.dropFirst().first {
    case "on": HookDebugLog.setEnabled(true); print("Hook debug log on: \(HookDebugLog.logURL.path)")
    case "off": HookDebugLog.setEnabled(false); print("Hook debug log off")
    default: print("Hook debug log is \(HookDebugLog.isEnabled ? "on" : "off"): \(HookDebugLog.logURL.path)")
    }
default:
    print(usage)
    exit(args.isEmpty || args.first == "help" ? 0 : 1)
}
