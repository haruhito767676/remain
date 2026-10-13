import Foundation
import Observation

/// Owns the engine, applies its decision to the OS, and schedules expiry.
@MainActor
@Observable
public final class WakeCoordinator {
    public private(set) var snapshot: WakeSnapshot = .idle
    public private(set) var settings: WakeSettings

    @ObservationIgnored private var engine: WakeEngine
    @ObservationIgnored private let assertions: any SleepAssertionProviding
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private let probe: any SessionProbing
    @ObservationIgnored private let pollInterval: Duration
    /// Called for every effect the engine reports (notifications, completion actions).
    @ObservationIgnored public var onEffect: (@MainActor (WakeEffect) -> Void)?

    public init(
        settings: WakeSettings = WakeSettings(),
        assertions: any SleepAssertionProviding,
        probe: any SessionProbing = SystemSessionProbe(),
        pollInterval: Duration = .seconds(3),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.probe = probe
        self.pollInterval = pollInterval
        self.settings = settings
        self.engine = WakeEngine(settings: settings)
        self.assertions = assertions
        self.now = now
        refresh()
    }

    public func receive(_ event: AgentEvent) {
        let effects = engine.handle(event, at: now())
        refresh()
        effects.forEach { onEffect?($0) }
    }

    public func update(power: PowerState) {
        let effects = engine.setPower(power)
        refresh()
        effects.forEach { onEffect?($0) }
    }

    public func setManual(_ mode: ManualMode) {
        engine.setManual(mode)
        refresh()
    }

    public func setManual(minutes: Int?) {
        if let minutes {
            setManual(.until(now().addingTimeInterval(TimeInterval(minutes) * 60)))
        } else {
            setManual(.indefinite)
        }
    }

    public func update(settings: WakeSettings) {
        self.settings = settings
        engine.settings = settings
        refresh()
    }

    private func refresh() {
        engine.expire(at: now())
        snapshot = engine.snapshot()
        assertions.apply(snapshot.prevention)
        scheduleExpiry()
        ensurePolling()
    }

    /// Looks for sessions that ended without telling us: the Claude Code process is gone,
    /// or the user interrupted it (no `Stop` hook fires for that).
    func checkLiveness() {
        var ended = false
        for session in engine.sessions.values {
            if let pid = session.pid, !probe.isAlive(pid: pid) {
                engine.end(session.id)
                ended = true
            } else if let path = session.transcriptPath, let offset = session.scanOffset {
                let scan = probe.scanTranscript(path: path, from: offset)
                if scan.interrupted {
                    engine.end(session.id)
                    ended = true
                } else if scan.newOffset != offset {
                    engine.setScanOffset(scan.newOffset, for: session.id)
                }
            }
        }
        if ended { refresh() }
    }

    func describeSessions() -> String {
        let t = now()
        let lines = engine.sessions.values.sorted { $0.startedAt < $1.startedAt }.map { s -> String in
            let pid = s.pid.map { "pid=\($0) alive=\(probe.isAlive(pid: $0))" } ?? "pid=none"
            let file = s.transcriptPath.map { path -> String in
                let size = TranscriptScanner.fileSize(atPath: path).map(String.init) ?? "missing"
                return "transcript=\((path as NSString).lastPathComponent) scanned=\(s.scanOffset.map(String.init) ?? "none")/size=\(size)"
            } ?? "transcript=none"
            return "\(s.id.prefix(8)) \(s.phase.rawValue) age=\(Int(t.timeIntervalSince(s.startedAt)))s idle=\(Int(t.timeIntervalSince(s.lastSeen)))s \(pid) \(file)"
        }
        let p = engine.power
        let power = "power: onBattery=\(p.onBattery) battery=\(p.batteryPercent.map { "\($0)%" } ?? "n/a") lowPower=\(p.lowPowerMode) thermal=\(p.thermal) blocked=\(String(describing: snapshot.blockedBy))"
        return (lines.isEmpty ? ["no sessions"] : lines).appending(power).joined(separator: "\n")
    }

    /// Polls only while there are sessions to watch.
    private func ensurePolling() {
        guard pollTask == nil, !engine.sessions.isEmpty else { return }
        pollTask = Task { [weak self, pollInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: pollInterval)
                guard let self else { return }
                checkLiveness()
                if engine.sessions.isEmpty {
                    pollTask = nil
                    return
                }
            }
        }
    }

    private func scheduleExpiry() {
        expiryTask?.cancel()
        guard let deadline = engine.nextDeadline() else { return }
        let delay = max(deadline.timeIntervalSince(now()), 0.1)
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}

private extension Array {
    func appending(_ element: Element) -> [Element] { self + [element] }
}
