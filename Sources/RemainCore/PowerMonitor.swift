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

    public init(onBattery: Bool = false, batteryPercent: Int? = nil, lowPowerMode: Bool = false, thermal: ThermalLevel = .nominal) {
        self.onBattery = onBattery
        self.batteryPercent = batteryPercent
        self.lowPowerMode = lowPowerMode
        self.thermal = thermal
    }
}

/// Watches battery, Low Power Mode and thermal state and reports changes on the main actor.
@MainActor
public final class SystemPowerMonitor {
    public var onChange: ((PowerState) -> Void)?
    private var runLoopSource: CFRunLoopSource?
    private var observers: [NSObjectProtocol] = []

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
        onChange?(Self.read())
    }

    public static func read() -> PowerState {
        var state = PowerState(
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermal: ThermalLevel(ProcessInfo.processInfo.thermalState)
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
