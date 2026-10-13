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
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        let data = try Data(contentsOf: settingsURL)
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x09 || $0 == 0x0D }) { return [:] }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw InstallError.invalidSettings("top level is not an object")
            }
            return object
        } catch let error as InstallError {
            throw error
        } catch {
            // Never overwrite a file we cannot read.
            throw InstallError.invalidSettings(error.localizedDescription)
        }
    }

    private func save(_ root: [String: Any]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: settingsURL.path) {
            let backup = settingsURL.appendingPathExtension("remain-backup")
            if !fm.fileExists(atPath: backup.path) { try fm.copyItem(at: settingsURL, to: backup) }
        }
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: settingsURL, options: .atomic)
    }
}
