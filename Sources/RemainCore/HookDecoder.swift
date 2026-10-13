import Foundation

/// Turns what each tool's hook delivers (JSON on stdin, sometimes an argument) into an `AgentEvent`,
/// and says what, if anything, the hook must print back.
public enum HookDecoder {
    public static func decode(agent: AgentKind, eventName: String?, stdin: Data) -> AgentEvent? {
        switch agent {
        case .claudeCode, .codex:
            return (try? JSONDecoder().decode(HookPayload.self, from: stdin))?.event(for: agent)
        case .antigravity:
            guard let eventName, let payload = try? JSONDecoder().decode(AntigravityPayload.self, from: stdin) else { return nil }
            return payload.event(named: eventName)
        case .command:
            return nil
        }
    }

    /// Antigravity expects JSON on stdout for its hooks (and a `decision` for `Stop`);
    /// Claude Code would feed plain stdout into the model, so it must stay silent.
    public static func response(agent: AgentKind, eventName: String?) -> String? {
        guard agent == .antigravity else { return nil }
        return eventName == "Stop" ? #"{"decision":"allow"}"# : "{}"
    }
}

/// The fields of Antigravity's hook input that remAIn uses. The event name is not part of the
/// payload, so it is passed on the command line (`remain hook antigravity <Event>`).
struct AntigravityPayload: Decodable {
    var conversationId: String
    var workspacePaths: [String]?
    var transcriptPath: String?
    var fullyIdle: Bool?
    var terminationReason: String?

    func event(named name: String) -> AgentEvent? {
        let kind: AgentEvent.Kind
        switch name {
        case "SessionStart", "PreInvocation":
            // There is no "prompt submitted" hook: a new model call means work is starting.
            kind = .start
        case "PostInvocation", "PostToolUse":
            kind = .activity
        case "Stop":
            // fullyIdle == false: background commands are still running, the agent is not done.
            kind = fullyIdle == false ? .activity : .finish
        default:
            return nil
        }
        return AgentEvent(sessionID: conversationId, cwd: workspacePaths?.first, kind: kind, agent: .antigravity)
    }
}
