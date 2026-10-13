import Foundation
import IOKit.ps

public enum ThermalLevel: Int, Codable, Comparable, Sendable {
    case nominal, fair, serious, critical

    public static func < (lhs: ThermalLevel, rhs: ThermalLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }
}

/// What the machine is doing power-wise. Desktop Macs report `onBattery == false` and no percentage.
public struct PowerState: Codable, Equatable, Sendable {
    public var onBattery = false
    public var batteryPercent: Int?
    public var lowPowerMode = false
    public var thermal: ThermalLevel = .nominal
    public var lidClosed = false

    public init(onBattery: Bool = false, batteryPercent: Int? = nil, lowPowerMode: Bool = false,
                thermal: ThermalLevel = .nominal, lidClosed: Bool = false) {
        self.onBattery = onBattery
        self.batteryPercent = batteryPercent
        self.lowPowerMode = lowPowerMode
        self.thermal = thermal
        self.lidClosed = lidClosed
    }
}

/// Watches battery, Low Power Mode and thermal state and reports changes on the main actor.
@MainActor
public final class SystemPowerMonitor {
    public var onChange: ((PowerState) -> Void)?
    private var runLoopSource: CFRunLoopSource?
    private var observers: [NSObjectProtocol] = []
    private var lidTimer: Timer?
    private var lastPublished: PowerState?

    /// The lid has no change notification we can use, so it is polled; only do that while it matters.
    public var watchesLid = false {
        didSet {
            guard watchesLid != oldValue else { return }
            lidTimer?.invalidate()
            lidTimer = nil
            guard watchesLid else { return }
            lidTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.publish() }
            }
            publish()
        }
    }

    public init() {}

    public func start() {
        // IOKit power-source changes (plug / unplug / percentage).
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<SystemPowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.publish() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        let center = NotificationCenter.default
        for name in [ProcessInfo.thermalStateDidChangeNotification, .NSProcessInfoPowerStateDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.publish() }
            })
        }
        publish()
    }

    private func publish() {
        let state = Self.read()
        guard state != lastPublished else { return }
        lastPublished = state
        onChange?(state)
    }

    /// `AppleClamshellState` on the power-management root domain; false on desktops.
    static func isLidClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else { return false }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
        return (value?.takeRetainedValue() as? Bool) ?? false
    }

    public static func read() -> PowerState {
        var state = PowerState(
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermal: ThermalLevel(ProcessInfo.processInfo.thermalState),
            lidClosed: isLidClosed()
        )
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return state }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            state.onBattery = description[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
            if let current = description[kIOPSCurrentCapacityKey] as? Int,
               let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 {
                state.batteryPercent = Int((Double(current) / Double(max) * 100).rounded())
            }
        }
        return state
    }
}
