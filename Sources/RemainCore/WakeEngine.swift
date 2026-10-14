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
    public var agent: AgentKind = .claudeCode
    /// The tool said work continues in the background, so silence does not mean "interrupted".
    public var background = false
}

extension AgentSession {
    /// A session starting from `event`. The transcript is only scanned for interruptions when we know
    /// how that tool records them.
    static func begin(_ event: AgentEvent, at now: Date) -> AgentSession {
        let scans = event.agent.scansTranscriptForInterruption
        let offset = scans ? (event.transcriptSize ?? (event.transcriptPath != nil ? 0 : nil)) : nil
        return AgentSession(
            id: event.sessionID, phase: .working, startedAt: now, lastSeen: now, cwd: event.cwd,
            pid: event.pid, transcriptPath: scans ? event.transcriptPath : nil, scanOffset: offset, agent: event.agent
        )
    }
}

/// Something worth telling the user about, emitted when the engine's state changes.
public enum WakeEffect: Equatable, Sendable {
    /// A working session finished (`Stop`, `StopFailure`, `SessionEnd`).
    case sessionFinished(cwd: String?, duration: TimeInterval)
    /// A working session ended without telling us (the process vanished, or it went silent past the
    /// safety timeout), so keeping the Mac awake for it is over.
    case sessionStopped(cwd: String?, duration: TimeInterval)
    /// A working session is now blocked on the user.
    case needsAttention(cwd: String?)
    /// The last session finished and nothing else (including a manual hold) is holding the Mac.
    case allFinished(duration: TimeInterval)
    /// A hold that was wanted had to be released because of power conditions.
    case holdSuspended(HoldBlock)
    /// The lid-closed time limit ran out: the Mac will sleep when the lid is closed.
    case lidLimitReached
}

/// Why a wanted hold is not being applied.
public enum HoldBlock: Codable, Equatable, Sendable {
    case lowBattery(percent: Int)
    case onBatteryPower
    case lowPowerMode
    case overheating
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
    /// Let the Mac sleep when the battery falls to this level (0 = never). Resumes 5 points above.
    public var batteryCutoffPercent = 20
    /// Never hold while running on battery.
    public var holdOnlyOnAC = false
    public var respectLowPowerMode = false
    /// Let the Mac sleep when macOS reports a critical thermal state.
    public var releaseWhenOverheating = true
    /// Keep running when the lid is closed while a hold is wanted (needs one-time system setup).
    public var keepRunningWithLidClosed = false
    /// Safety limit for lid-closed operation, counted from the start of the hold.
    public var lidClosedLimit: TimeInterval = 3 * 60 * 60

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
        batteryCutoffPercent = try c.decodeIfPresent(Int.self, forKey: .batteryCutoffPercent) ?? d.batteryCutoffPercent
        holdOnlyOnAC = try c.decodeIfPresent(Bool.self, forKey: .holdOnlyOnAC) ?? d.holdOnlyOnAC
        respectLowPowerMode = try c.decodeIfPresent(Bool.self, forKey: .respectLowPowerMode) ?? d.respectLowPowerMode
        releaseWhenOverheating = try c.decodeIfPresent(Bool.self, forKey: .releaseWhenOverheating) ?? d.releaseWhenOverheating
        keepRunningWithLidClosed = try c.decodeIfPresent(Bool.self, forKey: .keepRunningWithLidClosed) ?? d.keepRunningWithLidClosed
        lidClosedLimit = try c.decodeIfPresent(TimeInterval.self, forKey: .lidClosedLimit) ?? d.lidClosedLimit
    }
}

/// Immutable view of the engine state, used by UI and IPC.
public struct WakeSnapshot: Codable, Equatable, Sendable {
    public var prevention: SleepPrevention
    public var workingCount: Int
    public var waitingCount: Int
    public var manual: ManualMode
    /// Set when a hold is wanted but power conditions prevent it.
    public var blockedBy: HoldBlock?
    /// Whether closing the lid should *not* put the Mac to sleep right now.
    public var preventLidSleep: Bool

    public init(prevention: SleepPrevention, workingCount: Int, waitingCount: Int, manual: ManualMode,
                blockedBy: HoldBlock? = nil, preventLidSleep: Bool = false) {
        self.prevention = prevention
        self.workingCount = workingCount
        self.waitingCount = waitingCount
        self.manual = manual
        self.blockedBy = blockedBy
        self.preventLidSleep = preventLidSleep
    }

    public static let idle = WakeSnapshot(prevention: .none, workingCount: 0, waitingCount: 0, manual: .off)
}

/// Pure state machine: decides whether the Mac should stay awake.
/// All time is passed in explicitly, which keeps it deterministic and testable.
public struct WakeEngine: Sendable {
    public private(set) var sessions: [String: AgentSession] = [:]
    public private(set) var manual: ManualMode = .off
    public var settings: WakeSettings { didSet { updateBatteryLatch() } }
    public private(set) var power = PowerState()
    /// Hysteresis: once the battery cutoff trips it stays tripped until 5 points above it.
    private var batteryLatched = false
    /// When lid-closed prevention began within the current hold, and whether its limit has run out.
    public private(set) var lidSince: Date?
    public private(set) var lidLimitHit = false

    public init(settings: WakeSettings = WakeSettings()) {
        self.settings = settings
    }

    @discardableResult
    public mutating func handle(_ event: AgentEvent, at now: Date) -> [WakeEffect] {
        let id = event.sessionID
        switch event.kind {
        case .prompt:
            // A brand-new conversation has no transcript file yet when its first prompt fires,
            // so a missing size means "start scanning from the beginning".
            sessions[id] = AgentSession.begin(event, at: now)
            return []
        case .start:
            // For tools that only tell us "a model call is starting": keep the session if there is one.
            if var session = sessions[id] {
                session.phase = .working
                session.background = false
                session.lastSeen = now
                session.pid = event.pid ?? session.pid
                sessions[id] = session
            } else {
                sessions[id] = AgentSession.begin(event, at: now)
            }
            return []
        case .background:
            guard var session = sessions[id] else { return [] }
            session.background = true
            session.lastSeen = now
            sessions[id] = session
            return []
        case .interrupted:
            // The user is present: end quietly, like an interruption found in the transcript.
            sessions[id] = nil
            return []
        case .activity:
            // Unknown sessions are ignored on purpose: a late hook arriving after `Stop`
            // must not resurrect a finished session.
            guard var session = sessions[id] else { return [] }
            session.phase = .working
            session.background = false
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

    /// Ends a session that vanished on its own (process gone): unlike an interruption the user is not
    /// necessarily there, so a working session reports `sessionStopped`.
    public mutating func endUnexpectedly(_ id: String, at now: Date) -> [WakeEffect] {
        guard let session = sessions.removeValue(forKey: id) else { return [] }
        return stoppedEffects(for: session, at: now)
    }

    private func stoppedEffects(for session: AgentSession, at now: Date) -> [WakeEffect] {
        session.phase == .working ? [.sessionStopped(cwd: session.cwd, duration: now.timeIntervalSince(session.startedAt))] : []
    }

    public mutating func setScanOffset(_ offset: UInt64, for id: String) {
        sessions[id]?.scanOffset = offset
    }

    public mutating func setManual(_ mode: ManualMode) {
        manual = mode
    }

    public struct Expiry: Equatable, Sendable {
        public var sessionsTimedOut = 0
        public var manualElapsed = false
        public var effects: [WakeEffect] = []
    }

    /// Drops dead sessions and an elapsed manual timer, and reports what it dropped.
    @discardableResult
    public mutating func expire(at now: Date) -> Expiry {
        var expiry = Expiry()
        let alive = sessions.filter { now.timeIntervalSince($0.value.lastSeen) < timeout(for: $0.value) }
        expiry.sessionsTimedOut = sessions.count - alive.count
        expiry.effects = sessions.filter { alive[$0.key] == nil }.values.flatMap { stoppedEffects(for: $0, at: now) }
        sessions = alive
        if case .until(let end) = manual, end <= now {
            manual = .off
            expiry.manualElapsed = true
        }
        return expiry
    }

    /// How long a session may stay silent before it is dropped: the general safety net, or the shorter
    /// per-tool limit for tools whose interruptions are invisible (unless a background task was announced).
    func timeout(for session: AgentSession) -> TimeInterval {
        if !session.background, let quiet = session.agent.quietTimeout {
            return min(quiet, settings.sessionTimeout)
        }
        return settings.sessionTimeout
    }

    /// Sessions that currently keep the Mac awake (working, or waiting if so configured).
    public var holdingSessions: [AgentSession] {
        sessions.values.filter { $0.phase == .working || (settings.holdWhileWaiting && $0.phase == .waiting) }
    }

    public func snapshot() -> WakeSnapshot {
        let working = sessions.values.filter { $0.phase == .working }.count
        let waiting = sessions.values.filter { $0.phase == .waiting }.count
        let blocked = wantsHold ? block : nil
        let level: SleepPrevention = (wantsHold && blocked == nil)
            ? (settings.keepDisplayOn ? .systemAndDisplay : .system)
            : .none
        return WakeSnapshot(
            prevention: level, workingCount: working, waitingCount: waiting, manual: manual,
            blockedBy: blocked, preventLidSleep: wantsLidPrevention
        )
    }

    /// Lid-closed operation is wanted, allowed and still within its time limit.
    var wantsLidPrevention: Bool {
        settings.keepRunningWithLidClosed && wantsHold && block == nil && !lidLimitHit
    }

    /// Tracks the lid-closed time limit. Call with the current time whenever state may have changed.
    @discardableResult
    public mutating func updateLid(at now: Date) -> [WakeEffect] {
        guard settings.keepRunningWithLidClosed, wantsHold else {
            lidSince = nil
            lidLimitHit = false
            return []
        }
        if lidSince == nil { lidSince = now }
        if !lidLimitHit, let since = lidSince, now.timeIntervalSince(since) >= settings.lidClosedLimit {
            lidLimitHit = true
            return [.lidLimitReached]
        }
        return []
    }

    /// Whether anything (agent, manual timer) wants the Mac to stay awake, ignoring power conditions.
    var wantsHold: Bool {
        let working = sessions.values.contains { $0.phase == .working }
        let waiting = sessions.values.contains { $0.phase == .waiting }
        return working || manual != .off || (settings.holdWhileWaiting && waiting)
    }

    var block: HoldBlock? {
        // A closed Mac, often in a bag, cannot shed heat: be stricter than usual.
        let enclosed = settings.keepRunningWithLidClosed && power.lidClosed
        if (enclosed && power.thermal >= .serious) || (settings.releaseWhenOverheating && power.thermal >= .critical) {
            return .overheating
        }
        if batteryLatched, let percent = power.batteryPercent { return .lowBattery(percent: percent) }
        if settings.respectLowPowerMode && power.lowPowerMode { return .lowPowerMode }
        if settings.holdOnlyOnAC && power.onBattery { return .onBatteryPower }
        return nil
    }

    private mutating func updateBatteryLatch() {
        guard settings.batteryCutoffPercent > 0, power.onBattery, let percent = power.batteryPercent else {
            batteryLatched = false
            return
        }
        if percent <= settings.batteryCutoffPercent {
            batteryLatched = true
        } else if percent >= settings.batteryCutoffPercent + 5 {
            batteryLatched = false
        }
    }

    /// Feeds in the current power conditions. Reports when a wanted hold gets suspended.
    @discardableResult
    public mutating func setPower(_ new: PowerState) -> [WakeEffect] {
        let before = wantsHold ? block : nil
        power = new
        updateBatteryLatch()
        if before == nil, wantsHold, let after = block { return [.holdSuspended(after)] }
        return []
    }

    /// The next moment at which `expire` would change something, if any.
    public func nextDeadline() -> Date? {
        var deadlines = sessions.values.map { $0.lastSeen.addingTimeInterval(timeout(for: $0)) }
        if case .until(let end) = manual { deadlines.append(end) }
        if let since = lidSince, !lidLimitHit { deadlines.append(since.addingTimeInterval(settings.lidClosedLimit)) }
        return deadlines.min()
    }
}
