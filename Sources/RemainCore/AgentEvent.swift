import Foundation

/// Normalised signal about what an AI agent session is doing.
public struct AgentEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        /// The user submitted a prompt: the agent starts working.
        case prompt
        /// Work is under way: creates the session if unknown, otherwise just refreshes it.
        /// For tools without a "prompt submitted" hook.
        case start
        /// The agent is still active (e.g. a tool is running). Only refreshes known sessions.
        case activity
        /// The agent stopped for now but work continues in the background (a long command): stay awake,
        /// and do not apply the per-tool quiet timeout until something else is heard.
        case background
        /// The agent is blocked on the user (permission prompt, idle prompt).
        case attention
        /// The agent finished, failed, or the session ended.
        case finish
        /// The user interrupted the agent (for tools that tell us so directly).
        case interrupted
    }

    public var sessionID: String
    public var cwd: String?
    public var kind: Kind
    /// Claude Code process that owns the session (found by the `remain hook` CLI).
    public var pid: Int32?
    public var transcriptPath: String?
    /// Size of the transcript when the event fired; later scans start from here.
    public var transcriptSize: UInt64?
    public var agent: AgentKind

    public init(
        sessionID: String, cwd: String? = nil, kind: Kind,
        pid: Int32? = nil, transcriptPath: String? = nil, transcriptSize: UInt64? = nil,
        agent: AgentKind = .claudeCode
    ) {
        self.sessionID = sessionID
        self.cwd = cwd
        self.kind = kind
        self.pid = pid
        self.transcriptPath = transcriptPath
        self.transcriptSize = transcriptSize
        self.agent = agent
    }
}

/// The subset of the Claude Code hook JSON (delivered on stdin) that remAIn cares about.
public struct HookPayload: Codable, Equatable, Sendable {
    public var sessionID: String
    public var eventName: String
    public var cwd: String?
    public var notificationType: String?
    public var transcriptPath: String?
    /// Added by the `remain hook` CLI, not by Claude Code.
    public var claudePID: Int32?
    public var transcriptSize: UInt64?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case eventName = "hook_event_name"
        case cwd
        case notificationType = "notification_type"
        case transcriptPath = "transcript_path"
        case claudePID = "claude_pid"
        case transcriptSize = "transcript_size"
    }

    public init(sessionID: String, eventName: String, cwd: String? = nil, notificationType: String? = nil) {
        self.sessionID = sessionID
        self.eventName = eventName
        self.cwd = cwd
        self.notificationType = notificationType
    }

    /// Maps a Claude Code hook event to an agent event. Unknown events yield `nil`.
    public var agentEvent: AgentEvent? { event(for: .claudeCode) }

    /// Claude Code and Codex share this payload shape and almost all event names.
    public func event(for agent: AgentKind) -> AgentEvent? {
        let kind: AgentEvent.Kind
        switch eventName {
        case "UserPromptSubmit": kind = .prompt
        case "PreToolUse", "PostToolUse": kind = .activity
        case "Notification", "PermissionRequest": kind = .attention
        case "Stop", "StopFailure", "SessionEnd": kind = .finish
        case "Interrupt": kind = .interrupted
        default: return nil
        }
        return AgentEvent(
            sessionID: sessionID, cwd: cwd, kind: kind,
            pid: claudePID,
            transcriptPath: agent.scansTranscriptForInterruption ? transcriptPath : nil,
            transcriptSize: agent.scansTranscriptForInterruption ? transcriptSize : nil,
            agent: agent
        )
    }
}
