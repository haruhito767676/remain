import Foundation

/// Adds / removes remAIn's entries in Claude Code's `settings.json` without touching anything else.
public struct HookInstaller: Sendable {
    public static let events = [
        "UserPromptSubmit", "PreToolUse", "PostToolUse",
        "Notification", "Stop", "StopFailure", "SessionEnd",
    ]

    public enum InstallError: Error, CustomStringConvertible {
        case invalidSettings(String)
        public var description: String {
            switch self {
            case .invalidSettings(let reason): "Could not parse Claude Code settings: \(reason)"
            }
        }
    }

    public let settingsURL: URL
    /// Absolute path of the `remain` executable.
    public let executablePath: String

    public init(settingsURL: URL = RemainPaths.claudeSettingsURL, executablePath: String) {
        self.settingsURL = settingsURL
        self.executablePath = executablePath
    }

    var command: String { Self.shellQuote(executablePath) + " hook" }

    public func isInstalled() -> Bool {
        guard let root = try? loadSettings(), let hooks = root["hooks"] as? [String: Any] else { return false }
        return Self.events.allSatisfy { event in
            groups(in: hooks, event).contains { group in
                commands(in: group).contains(where: Self.isRemainCommand)
            }
        }
    }

    /// Installed, but pointing at a different executable than this app's (it was moved or replaced).
    public func needsRepair() -> Bool {
        guard let root = try? loadSettings(), let hooks = root["hooks"] as? [String: Any] else { return false }
        let ours = Self.events.flatMap { event in
            groups(in: hooks, event).flatMap { commands(in: $0) }.filter(Self.isRemainCommand)
        }
        return !ours.isEmpty && ours.contains { $0 != command }
    }

    public func install() throws {
        var root = try loadSettings()
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in Self.events {
            var groups = Self.removingRemain(from: self.groups(in: hooks, event))
            groups.append([
                "hooks": [["type": "command", "command": command, "timeout": 5]],
            ])
            hooks[event] = groups
        }
        root["hooks"] = hooks
        try save(root)
    }

    public func uninstall() throws {
        var root = try loadSettings()
        guard var hooks = root["hooks"] as? [String: Any] else { return }
        for event in Self.events {
            let cleaned = Self.removingRemain(from: groups(in: hooks, event))
            hooks[event] = cleaned.isEmpty ? nil : cleaned
        }
        root["hooks"] = hooks.isEmpty ? nil : hooks
        try save(root)
    }

    // MARK: - Helpers

    private func groups(in hooks: [String: Any], _ event: String) -> [[String: Any]] {
        hooks[event] as? [[String: Any]] ?? []
    }

    private func commands(in group: [String: Any]) -> [String] {
        (group["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String }
    }

    /// Removes remAIn handlers; groups that become empty are dropped, foreign handlers are kept.
    private static func removingRemain(from groups: [[String: Any]]) -> [[String: Any]] {
        groups.compactMap { group in
            var group = group
            let handlers = (group["hooks"] as? [[String: Any]] ?? []).filter {
                !isRemainCommand($0["command"] as? String ?? "")
            }
            if handlers.isEmpty { return nil }
            group["hooks"] = handlers
            return group
        }
    }

    static func isRemainCommand(_ command: String) -> Bool {
        command.hasSuffix(" hook") && command.lowercased().contains("remain")
    }

    static func shellQuote(_ path: String) -> String {
        let safe = path.allSatisfy { $0.isLetter || $0.isNumber || "/._-".contains($0) }
        return safe ? path : "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func loadSettings() throws -> [String: Any] {
        do { return try JSONFile.load(settingsURL) } catch let error as JSONFile.Invalid {
            throw InstallError.invalidSettings(error.reason)
        }
    }

    private func save(_ root: [String: Any]) throws {
        try JSONFile.save(root, to: settingsURL)
    }
}

/// Antigravity keeps hooks in `~/.gemini/config/hooks.json`: top-level keys are hook names, so remAIn
/// owns exactly one key and never touches the others.
public struct AntigravityHookInstaller: Sendable {
    public static let hookName = "remain"
    static let plainEvents = ["SessionStart", "PreInvocation", "PostInvocation", "Stop"]
    static let toolEvents = ["PostToolUse"] // PreToolUse must answer with a decision, so we stay out of it

    public let configURL: URL
    public let executablePath: String

    public init(
        configURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gemini/config/hooks.json"),
        executablePath: String
    ) {
        self.configURL = configURL
        self.executablePath = executablePath
    }

    func command(for event: String) -> String {
        HookInstaller.shellQuote(executablePath) + " hook \(AgentKind.antigravity.cliName) \(event)"
    }

    func entry() -> [String: Any] {
        func handler(_ event: String) -> [String: Any] { ["type": "command", "command": command(for: event), "timeout": 5] }
        var hook: [String: Any] = [:]
        for event in Self.plainEvents { hook[event] = [handler(event)] }
        for event in Self.toolEvents { hook[event] = [["matcher": "", "hooks": [handler(event)]]] }
        return hook
    }

    private func ourCommands() -> [String] {
        guard let root = try? JSONFile.load(configURL), let ours = root[Self.hookName] as? [String: Any] else { return [] }
        var commands: [String] = []
        for event in Self.plainEvents {
            commands += (ours[event] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String }
        }
        for event in Self.toolEvents {
            for group in ours[event] as? [[String: Any]] ?? [] {
                commands += (group["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String }
            }
        }
        return commands
    }

    public func isInstalled() -> Bool {
        ourCommands().count == Self.plainEvents.count + Self.toolEvents.count
    }

    /// Installed, but pointing at a different executable than this app's.
    public func needsRepair() -> Bool {
        let commands = ourCommands()
        let expected = Set((Self.plainEvents + Self.toolEvents).map(command(for:)))
        return !commands.isEmpty && Set(commands) != expected
    }

    public func install() throws {
        var root: [String: Any]
        do { root = try JSONFile.load(configURL) } catch let error as JSONFile.Invalid {
            throw HookInstaller.InstallError.invalidSettings(error.reason)
        }
        root[Self.hookName] = entry()
        try JSONFile.save(root, to: configURL)
    }

    public func uninstall() throws {
        var root: [String: Any]
        do { root = try JSONFile.load(configURL) } catch let error as JSONFile.Invalid {
            throw HookInstaller.InstallError.invalidSettings(error.reason)
        }
        guard root[Self.hookName] != nil else { return }
        root[Self.hookName] = nil
        try JSONFile.save(root, to: configURL)
    }
}
