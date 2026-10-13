import Foundation
import RemainCore

extension HoldBlock {
    /// Short, localized explanation used in the menu and in notifications.
    var reason: String {
        switch self {
        case .lowBattery(let percent):
            String(localized: "Battery at \((Double(percent) / 100).formatted(.percent))")
        case .onBatteryPower:
            String(localized: "On battery power")
        case .lowPowerMode:
            String(localized: "Low Power Mode is on")
        case .overheating:
            String(localized: "The Mac is too hot")
        }
    }

    var symbolName: String {
        switch self {
        case .lowBattery: "battery.25percent"
        case .onBatteryPower: "battery.50percent"
        case .lowPowerMode: "battery.50percent"
        case .overheating: "thermometer.high"
        }
    }
}
