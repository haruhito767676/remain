import Foundation

/// The tools remAIn can follow.
public enum AgentKind: String, Codable, CaseIterable, Sendable {
    case claudeCode
    case antigravity
    case codex
    /// A command wrapped with `remain run`.
    case command

    public var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .antigravity: "Antigravity"
        case .codex: "Codex"
        case .command: "Command"
        }
    }

    /// Argument after `remain hook`.
    public var cliName: String {
        switch self {
        case .claudeCode: "claude"
        case .antigravity: "antigravity"
        case .codex: "codex"
        case .command: "run"
        }
    }

    public init?(cliName: String) {
        guard let kind = Self.allCases.first(where: { $0.cliName == cliName }) else { return nil }
        self = kind
    }

    /// Tools remAIn can connect to. Codex's hooks are decoded already but stay off this list until they
    /// have been checked against a real Codex; `command` (remain run) needs no integration.
    public static var integrable: [AgentKind] { [.claudeCode, .antigravity] }

    /// Does the conversation log reveal interruptions we know how to read?
    var scansTranscriptForInterruption: Bool { self == .claudeCode }

    /// Does an executable of this name belong to the tool's own process?
    func ownsProcess(named name: String) -> Bool {
        let lower = name.lowercased()
        switch self {
        case .claudeCode: return lower == "claude" || lower == "claude.exe"
        case .codex: return lower == "codex" || lower.hasPrefix("codex-")
        case .antigravity: return lower.contains("antigravity") || lower.hasPrefix("language_server")
        case .command: return false
        }
    }
}
