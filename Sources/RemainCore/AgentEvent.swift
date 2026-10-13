import Foundation

/// Normalised signal about what an AI agent session is doing.
public struct AgentEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// The user submitted a prompt: the agent starts working.
        case prompt
        /// The agent is still active (e.g. a tool is running). Only refreshes known sessions.
        case activity
        /// The agent is blocked on the user (permission prompt, idle prompt).
        case attention
        /// The agent finished, failed, or the session ended.
        case finish
    }

    public var sessionID: String
    public var cwd: String?
    public var kind: Kind

    public init(sessionID: String, cwd: String? = nil, kind: Kind) {
        self.sessionID = sessionID
        self.cwd = cwd
        self.kind = kind
    }
}

/// The subset of the Claude Code hook JSON (delivered on stdin) that remAIn cares about.
public struct HookPayload: Codable, Equatable, Sendable {
    public var sessionID: String
    public var eventName: String
    public var cwd: String?
    public var notificationType: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case eventName = "hook_event_name"
        case cwd
        case notificationType = "notification_type"
    }

    public init(sessionID: String, eventName: String, cwd: String? = nil, notificationType: String? = nil) {
        self.sessionID = sessionID
        self.eventName = eventName
        self.cwd = cwd
        self.notificationType = notificationType
    }

    /// Maps a Claude Code hook event to an agent event. Unknown events yield `nil`.
    public var agentEvent: AgentEvent? {
        let kind: AgentEvent.Kind
        switch eventName {
        case "UserPromptSubmit": kind = .prompt
        case "PreToolUse", "PostToolUse": kind = .activity
        case "Notification": kind = .attention
        case "Stop", "StopFailure", "SessionEnd": kind = .finish
        default: return nil
        }
        return AgentEvent(sessionID: sessionID, cwd: cwd, kind: kind)
    }
}
