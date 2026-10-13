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

    /// The event's name: Antigravity passes it as an argument, Claude Code and Codex inside the JSON.
    public static func eventName(agent: AgentKind, argument: String?, stdin: Data) -> String? {
        if let argument { return argument }
        return (try? JSONDecoder().decode(HookPayload.self, from: stdin))?.eventName
    }

    /// What the hook must print. Claude Code feeds plain stdout into the model, so it stays silent;
    /// Antigravity wants JSON for every hook (and a `decision` for `Stop`); Codex wants JSON from `Stop`
    /// but treats stdout of `UserPromptSubmit` as context, so only `Stop` answers.
    public static func response(agent: AgentKind, eventName: String?) -> String? {
        switch agent {
        case .antigravity: return eventName == "Stop" ? #"{"decision":"allow"}"# : "{}"
        case .codex: return eventName == "Stop" ? "{}" : nil
        case .claudeCode, .command: return nil
        }
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
            kind = fullyIdle == false ? .background : .finish
        default:
            return nil
        }
        return AgentEvent(sessionID: conversationId, cwd: workspacePaths?.first, kind: kind, agent: .antigravity)
    }
}
