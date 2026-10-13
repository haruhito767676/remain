import Foundation
import UserNotifications
import RemainCore

/// Thin wrapper over `UNUserNotificationCenter`. Does nothing when run outside an app bundle
/// (`swift run`), where the notification center is unavailable.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    func requestAuthorization() {
        guard let center else { return }
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// True when the user has turned remAIn's notifications off in System Settings.
    func isDenied() async -> Bool {
        guard let center else { return false }
        return await center.notificationSettings().authorizationStatus == .denied
    }

    func finished(cwd: String?, duration: TimeInterval) {
        let took = String(localized: "took \(Self.format(duration))")
        post(title: String(localized: "An agent finished its work"), body: [project(cwd), took].compactMap { $0 }.joined(separator: " · "))
    }

    func needsAttention(cwd: String?) {
        post(title: String(localized: "An agent needs your input"), body: project(cwd) ?? String(localized: "An agent is waiting for you."))
    }

    func lidLimitReached() {
        post(title: String(localized: "Lid-closed limit reached"), body: String(localized: "The Mac will sleep when you close the lid."))
    }

    func lidFailed(_ failure: LidFailure) {
        let body = switch failure {
        case .notSetUp: String(localized: "The system permission is not set up. Open Settings to set it up.")
        case .commandFailed: String(localized: "The system refused the change. Try setting it up again.")
        }
        post(title: String(localized: "Could not keep running with the lid closed"), body: body)
    }

    func holdSuspended(reason: String) {
        post(title: String(localized: "Letting your Mac sleep"), body: reason)
    }

    private func post(title: String, body: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func project(_ cwd: String?) -> String? {
        cwd.map { URL(fileURLWithPath: $0).lastPathComponent }.flatMap { $0.isEmpty ? nil : $0 }
    }

    static func format(_ seconds: TimeInterval) -> String {
        Duration.seconds(Int(seconds))
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }

    // Show banners even though the app is technically in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
