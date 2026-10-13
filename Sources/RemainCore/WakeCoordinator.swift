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
    /// Called for every effect the engine reports (notifications, completion actions).
    @ObservationIgnored public var onEffect: (@MainActor (WakeEffect) -> Void)?

    public init(
        settings: WakeSettings = WakeSettings(),
        assertions: any SleepAssertionProviding,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
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
