import Foundation

/// Opt-in diagnostics: when enabled, every hook invocation is recorded raw. Used to learn what a tool
/// really sends (for example when it interrupts), since documentation is often incomplete.
public enum HookDebugLog {
    static var flagURL: URL { RemainPaths.supportDirectory.appendingPathComponent("debug") }
    public static var logURL: URL { RemainPaths.supportDirectory.appendingPathComponent("hook-debug.jsonl") }

    public static var isEnabled: Bool { FileManager.default.fileExists(atPath: flagURL.path) }

    public static func setEnabled(_ enabled: Bool) {
        let fm = FileManager.default
        if enabled {
            try? fm.createDirectory(at: RemainPaths.supportDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            fm.createFile(atPath: flagURL.path, contents: nil)
        } else {
            try? fm.removeItem(at: flagURL)
        }
    }

    /// Never throws and never blocks the tool that called the hook.
    public static func record(agent: AgentKind, eventArgument: String?, stdin: Data, decoded: AgentEvent?, processes: [(pid: Int32, name: String)]) {
        guard isEnabled else { return }
        let entry: [String: Any] = [
            "time": ISO8601DateFormatter().string(from: Date()),
            "agent": agent.cliName,
            "eventArgument": eventArgument ?? NSNull(),
            "stdin": String(decoding: stdin.prefix(8000), as: UTF8.self),
            "decodedKind": decoded?.kind.rawValue ?? NSNull(),
            "decodedPID": decoded?.pid.map { Int($0) } as Any? ?? NSNull(),
            "ancestors": processes.map { "\($0.pid):\($0.name)" },
        ]
        guard var line = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]) else { return }
        line.append(UInt8(ascii: "\n"))
        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: logURL)
        }
    }
}
