import Foundation

public enum AgentPhase: String, Codable, Sendable {
    case working
    case waiting
}

public struct AgentSession: Equatable, Sendable {
    public var id: String
    public var phase: AgentPhase
    public var lastSeen: Date
    public var cwd: String?
}

public enum ManualMode: Codable, Equatable, Sendable {
    case off
    case until(Date)
    case indefinite
}

public struct WakeSettings: Codable, Equatable, Sendable {
    /// A session that has not reported anything for this long is considered dead.
    /// Protects against missed `Stop` events (interrupts, crashes).
    public var sessionTimeout: TimeInterval = 15 * 60
    /// Keep the Mac awake while an agent waits for the user (permission prompts).
    public var holdWhileWaiting = false
    /// Keep the display on as well. Off by default: agents do not need a lit screen.
    public var keepDisplayOn = false

    public init() {}
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

    public mutating func handle(_ event: AgentEvent, at now: Date) {
        let id = event.sessionID
        switch event.kind {
        case .prompt:
            sessions[id] = AgentSession(id: id, phase: .working, lastSeen: now, cwd: event.cwd)
        case .activity:
            // Unknown sessions are ignored on purpose: a late hook arriving after `Stop`
            // must not resurrect a finished session.
            guard var session = sessions[id] else { return }
            session.phase = .working
            session.lastSeen = now
            sessions[id] = session
        case .attention:
            guard var session = sessions[id] else { return }
            session.phase = .waiting
            session.lastSeen = now
            sessions[id] = session
        case .finish:
            sessions[id] = nil
        }
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
