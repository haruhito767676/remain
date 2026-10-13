import Foundation

public enum AgentPhase: String, Codable, Sendable {
    case working
    case waiting
}

public struct AgentSession: Equatable, Sendable {
    public var id: String
    public var phase: AgentPhase
    public var startedAt: Date
    public var lastSeen: Date
    public var cwd: String?
    /// Claude Code process; if it disappears the session is over.
    public var pid: Int32?
    public var transcriptPath: String?
    /// How far into the transcript interruption scanning has progressed.
    public var scanOffset: UInt64?
}

/// Something worth telling the user about, emitted when the engine's state changes.
public enum WakeEffect: Equatable, Sendable {
    /// A working session finished (`Stop`, `StopFailure`, `SessionEnd`).
    case sessionFinished(cwd: String?, duration: TimeInterval)
    /// A working session is now blocked on the user.
    case needsAttention(cwd: String?)
    /// The last session finished and nothing else (including a manual hold) is holding the Mac.
    case allFinished(duration: TimeInterval)
}

public enum CompletionAction: String, Codable, CaseIterable, Sendable {
    case nothing
    case turnDisplayOff
    case sleepMac
}

public enum ManualMode: Codable, Equatable, Sendable {
    case off
    case until(Date)
    case indefinite
}

public struct WakeSettings: Codable, Equatable, Sendable {
    /// A session that has not reported anything for this long is considered dead.
    /// Protects against missed `Stop` events (interrupts, crashes).
    /// Interruptions and dead processes are detected directly; this is only a safety net.
    public var sessionTimeout: TimeInterval = 60 * 60
    /// Keep the Mac awake while an agent waits for the user (permission prompts).
    public var holdWhileWaiting = false
    /// Keep the display on as well. Off by default: agents do not need a lit screen.
    public var keepDisplayOn = false
    /// Notify when an agent finishes / needs input. Tasks shorter than `minimumNotifiableDuration` stay quiet.
    public var notifyOnFinish = true
    public var notifyOnAttention = true
    public var minimumNotifiableDuration: TimeInterval = 30
    /// Runs once the last agent has finished (after a short grace period).
    public var completionAction: CompletionAction = .nothing

    public init() {}

    // Custom decoding so settings saved by older versions keep working when new keys are added.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WakeSettings()
        sessionTimeout = try c.decodeIfPresent(TimeInterval.self, forKey: .sessionTimeout) ?? d.sessionTimeout
        holdWhileWaiting = try c.decodeIfPresent(Bool.self, forKey: .holdWhileWaiting) ?? d.holdWhileWaiting
        keepDisplayOn = try c.decodeIfPresent(Bool.self, forKey: .keepDisplayOn) ?? d.keepDisplayOn
        notifyOnFinish = try c.decodeIfPresent(Bool.self, forKey: .notifyOnFinish) ?? d.notifyOnFinish
        notifyOnAttention = try c.decodeIfPresent(Bool.self, forKey: .notifyOnAttention) ?? d.notifyOnAttention
        minimumNotifiableDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .minimumNotifiableDuration)
            ?? d.minimumNotifiableDuration
        completionAction = try c.decodeIfPresent(CompletionAction.self, forKey: .completionAction) ?? d.completionAction
    }
}

/// Immutable view of the engine state, used by UI and IPC.
public struct WakeSnapshot: Codable, Equatable, Sendable {
    public var prevention: SleepPrevention
    public var workingCount: Int
    public var waitingCount: Int
    public var manual: ManualMode

    public static let idle = WakeSnapshot(prevention: .none, workingCount: 0, waitingCount: 0, manual: .off)
}

/// Pure state machine: decides whether the Mac should stay awake.
/// All time is passed in explicitly, which keeps it deterministic and testable.
public struct WakeEngine: Sendable {
    public private(set) var sessions: [String: AgentSession] = [:]
    public private(set) var manual: ManualMode = .off
    public var settings: WakeSettings

    public init(settings: WakeSettings = WakeSettings()) {
        self.settings = settings
    }

    @discardableResult
    public mutating func handle(_ event: AgentEvent, at now: Date) -> [WakeEffect] {
        let id = event.sessionID
        switch event.kind {
        case .prompt:
            sessions[id] = AgentSession(
                id: id, phase: .working, startedAt: now, lastSeen: now, cwd: event.cwd,
                pid: event.pid, transcriptPath: event.transcriptPath, scanOffset: event.transcriptSize
            )
            return []
        case .activity:
            // Unknown sessions are ignored on purpose: a late hook arriving after `Stop`
            // must not resurrect a finished session.
            guard var session = sessions[id] else { return [] }
            session.phase = .working
            session.lastSeen = now
            session.pid = event.pid ?? session.pid
            sessions[id] = session
            return []
        case .attention:
            guard var session = sessions[id] else { return [] }
            let wasWorking = session.phase == .working
            session.phase = .waiting
            session.lastSeen = now
            sessions[id] = session
            return wasWorking ? [.needsAttention(cwd: session.cwd)] : []
        case .finish:
            // Only the first finish event of a session reports; `Stop` followed by `SessionEnd` stays quiet.
            guard let session = sessions.removeValue(forKey: id) else { return [] }
            let duration = now.timeIntervalSince(session.startedAt)
            var effects: [WakeEffect] = [.sessionFinished(cwd: session.cwd, duration: duration)]
            if sessions.isEmpty && manual == .off {
                effects.append(.allFinished(duration: duration))
            }
            return effects
        }
    }

    /// Ends a session silently (interrupted or process gone): the user is present, so no
    /// notification and no completion action.
    public mutating func end(_ id: String) {
        sessions[id] = nil
    }

    public mutating func setScanOffset(_ offset: UInt64, for id: String) {
        sessions[id]?.scanOffset = offset
    }

    public mutating func setManual(_ mode: ManualMode) {
        manual = mode
    }

    /// Drops dead sessions and an elapsed manual timer.
    public mutating func expire(at now: Date) {
        sessions = sessions.filter { now.timeIntervalSince($0.value.lastSeen) < settings.sessionTimeout }
        if case .until(let end) = manual, end <= now {
            manual = .off
        }
    }

    public func snapshot() -> WakeSnapshot {
        let working = sessions.values.filter { $0.phase == .working }.count
        let waiting = sessions.values.filter { $0.phase == .waiting }.count
        let manualActive = manual != .off
        let holding = working > 0 || manualActive || (settings.holdWhileWaiting && waiting > 0)
        let level: SleepPrevention = holding
            ? (settings.keepDisplayOn ? .systemAndDisplay : .system)
            : .none
        return WakeSnapshot(prevention: level, workingCount: working, waitingCount: waiting, manual: manual)
    }

    /// The next moment at which `expire` would change something, if any.
    public func nextDeadline() -> Date? {
        var deadlines = sessions.values.map { $0.lastSeen.addingTimeInterval(settings.sessionTimeout) }
        if case .until(let end) = manual { deadlines.append(end) }
        return deadlines.min()
    }
}
