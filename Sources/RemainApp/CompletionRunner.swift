import Foundation
import RemainCore

/// Runs the user-chosen action after all agents are done, unless new work shows up during a grace period.
@MainActor
final class CompletionRunner {
    static let gracePeriod: Duration = .seconds(10)

    private let coordinator: WakeCoordinator
    private var pending: Task<Void, Never>?

    init(coordinator: WakeCoordinator) {
        self.coordinator = coordinator
    }

    func schedule(_ action: CompletionAction) {
        pending?.cancel()
        guard action != .nothing else { return }
        pending = Task { [coordinator] in
            try? await Task.sleep(for: Self.gracePeriod)
            guard !Task.isCancelled else { return }
            let s = coordinator.snapshot
            // Someone started a new prompt or a manual hold in the meantime: stand down.
            guard s.workingCount == 0, s.manual == .off else { return }
            Self.run(action)
        }
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }

    private static func run(_ action: CompletionAction) {
        let argument: String
        switch action {
        case .nothing: return
        case .turnDisplayOff: argument = "displaysleepnow"
        case .sleepMac: argument = "sleepnow"
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = [argument]
        try? process.run()
    }
}
