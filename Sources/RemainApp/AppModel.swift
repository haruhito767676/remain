import SwiftUI
import ServiceManagement
import RemainCore

@MainActor
@Observable
final class AppModel {
    let coordinator: WakeCoordinator
    let activity: ActivityLog
    var settingsTab: SettingsTab = .general
    private(set) var hooksInstalled = false
    private(set) var hooksError: String?
    private(set) var launchAtLogin = false
    /// Bumped while a manual timer runs so that "time left" in the menu stays current.
    private var clockTick = Date()

    @ObservationIgnored private let server = IPCServer()
    @ObservationIgnored private let notifier = Notifier()
    @ObservationIgnored private let completion: CompletionRunner
    @ObservationIgnored private let powerMonitor = SystemPowerMonitor()
    @ObservationIgnored private static let settingsKey = "wakeSettings"

    init() {
        let settings = Self.loadSettings()
        let activity = ActivityLog(store: FileActivityStore())
        self.activity = activity
        coordinator = WakeCoordinator(settings: settings, assertions: IOKitSleepAssertions(), activity: activity)
        completion = CompletionRunner(coordinator: coordinator)
        if settings.notifyOnFinish || settings.notifyOnAttention { notifier.requestAuthorization() }
        coordinator.onEffect = { [unowned self] effect in handle(effect) }
        let coordinator = coordinator
        do {
            try server.start { request in await coordinator.handle(request) }
        } catch {
            hooksError = String(localized: "Could not start receiving hook events: \(String(describing: error))")
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [coordinator] _ in
            MainActor.assumeIsolated { coordinator.shutdown() }
        }
        powerMonitor.onChange = { [coordinator] state in coordinator.update(power: state) }
        powerMonitor.start()
        refreshState()
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard let self else { return }
                // Keeps "time left" and "today" in the menu and the Activity tab current.
                if snapshot.prevention != .none { clockTick = Date() }
            }
        }
    }

    // MARK: - Presentation

    var snapshot: WakeSnapshot { coordinator.snapshot }
    var settings: WakeSettings { coordinator.settings }

    var symbolName: String {
        let s = snapshot
        if let block = s.blockedBy { return block.symbolName }
        if s.workingCount > 0 { return "sparkles" }
        if s.manual != .off || s.prevention != .none { return "cup.and.saucer.fill" }
        if s.waitingCount > 0 { return "hourglass" }
        return "moon.zzz"
    }

    var statusTitle: String {
        let s = snapshot
        if let block = s.blockedBy { return String(localized: "Sleep allowed: \(block.reason)") }
        if s.workingCount > 0 {
            return s.workingCount == 1
                ? String(localized: "An agent is working")
                : String(localized: "\(s.workingCount) agents working")
        }
        switch s.manual {
        case .indefinite: return String(localized: "Keeping Mac awake")
        case .until(let end):
            return String(localized: "Keeping Mac awake until \(Self.clock(end)) (\(remaining(until: end)) left)")
        case .off: break
        }
        if s.waitingCount > 0 { return String(localized: "An agent is waiting for you") }
        return String(localized: "Sleep allowed")
    }

    /// Current time, re-read whenever the tick fires so views that show durations stay fresh.
    var now: Date {
        _ = clockTick
        return Date()
    }

    /// "Today: 2h 14m", or nil while there is nothing worth showing.
    var todaySummary: String? {
        let intervals = ActivitySummary.all(activity.intervals, open: activity.open, now: now)
        let seconds = ActivitySummary.daily(intervals, now: now, days: 1).first?.total ?? 0
        guard seconds >= 60 else { return nil }
        return String(localized: "Today: \(ActivityView.format(seconds))")
    }

    /// Extra line shown while agents are working, so a running manual timer does not disappear from view.
    var manualHoldLine: String? {
        guard snapshot.workingCount > 0 else { return nil }
        switch snapshot.manual {
        case .off: return nil
        case .indefinite: return String(localized: "Manual: on")
        case .until(let end):
            return String(localized: "Manual: until \(Self.clock(end)) (\(remaining(until: end)) left)")
        }
    }

    private static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Rounded up to whole minutes, e.g. "23m" / "1h 5m".
    private func remaining(until end: Date) -> String {
        _ = clockTick // read so the view re-renders on every tick
        let minutes = max(1, Int((end.timeIntervalSinceNow / 60).rounded(.up)))
        return Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated, maximumUnitCount: 2))
    }

    // MARK: - Actions

    func update(_ change: (inout WakeSettings) -> Void) {
        var new = coordinator.settings
        change(&new)
        coordinator.update(settings: new)
        if let data = try? JSONEncoder().encode(new) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    private func handle(_ effect: WakeEffect) {
        let s = settings
        switch effect {
        case .sessionFinished(let cwd, let duration):
            if s.notifyOnFinish, duration >= s.minimumNotifiableDuration {
                notifier.finished(cwd: cwd, duration: duration)
            }
        case .needsAttention(let cwd):
            if s.notifyOnAttention { notifier.needsAttention(cwd: cwd) }
        case .allFinished(let duration):
            if duration >= s.minimumNotifiableDuration { completion.schedule(s.completionAction) }
        case .holdSuspended(let block):
            notifier.holdSuspended(reason: block.reason)
        }
    }

    func requestNotificationAuthorization() { notifier.requestAuthorization() }

    func installHooks() { runInstaller { try $0.install() } }
    func uninstallHooks() { runInstaller { try $0.uninstall() } }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            hooksError = String(localized: "Launch at login: \(error.localizedDescription)")
        }
        refreshState()
    }

    func refreshState() {
        hooksInstalled = installer()?.isInstalled() ?? false
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Private

    private func runInstaller(_ action: (HookInstaller) throws -> Void) {
        guard let installer = installer() else {
            hooksError = String(localized: "Could not find the remain command-line helper.")
            return
        }
        do {
            try action(installer)
            hooksError = nil
        } catch {
            hooksError = "\(error)"
        }
        refreshState()
    }

    /// The CLI lives in `remAIn.app/Contents/Helpers/remain`, or next to the binary during development.
    private func installer() -> HookInstaller? {
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/remain"),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("remain"),
        ].compactMap { $0 }
        guard let cli = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            return nil
        }
        return HookInstaller(executablePath: cli.path)
    }

    private static func loadSettings() -> WakeSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              var settings = try? JSONDecoder().decode(WakeSettings.self, from: data) else {
            return WakeSettings()
        }
        // The old default (15 min) cut off long tool runs. Interruptions are now detected directly,
        // so the timeout is only a safety net and the default moved to 1 hour.
        if settings.sessionTimeout == 15 * 60 { settings.sessionTimeout = WakeSettings().sessionTimeout }
        return settings
    }
}
