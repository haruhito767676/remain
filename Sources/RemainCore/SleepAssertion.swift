import Foundation
import IOKit.pwr_mgt

/// How aggressively the Mac is prevented from idling to sleep.
public enum SleepPrevention: Int, Codable, Comparable, Sendable {
    case none
    /// The system stays awake, but the display may turn off.
    case system
    /// Both the system and the display stay awake.
    case systemAndDisplay

    public static func < (lhs: SleepPrevention, rhs: SleepPrevention) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Abstraction over the power-management API so the logic can be tested without touching IOKit.
public protocol SleepAssertionProviding: Sendable {
    func apply(_ level: SleepPrevention)
}

/// IOKit-backed implementation. Holds at most one assertion per kind and releases it
/// as soon as it is no longer needed. Only call from a single actor/thread.
public final class IOKitSleepAssertions: SleepAssertionProviding, @unchecked Sendable {
    private var systemID = IOPMAssertionID(kIOPMNullAssertionID)
    private var displayID = IOPMAssertionID(kIOPMNullAssertionID)
    private let reason: String

    public init(reason: String = "remAIn is keeping this Mac awake") {
        self.reason = reason
    }

    public func apply(_ level: SleepPrevention) {
        update(&systemID,
               type: kIOPMAssertionTypePreventUserIdleSystemSleep,
               wanted: level >= .system)
        update(&displayID,
               type: kIOPMAssertionTypePreventUserIdleDisplaySleep,
               wanted: level >= .systemAndDisplay)
    }

    private func update(_ id: inout IOPMAssertionID, type: String, wanted: Bool) {
        let held = id != IOPMAssertionID(kIOPMNullAssertionID)
        switch (held, wanted) {
        case (false, true):
            var newID = IOPMAssertionID(kIOPMNullAssertionID)
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &newID
            )
            if result == kIOReturnSuccess { id = newID }
        case (true, false):
            IOPMAssertionRelease(id)
            id = IOPMAssertionID(kIOPMNullAssertionID)
        default:
            break
        }
    }
}
