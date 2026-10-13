import SwiftUI
import ServiceManagement
import RemainCore

@MainActor
@Observable
final class AppModel {
    let coordinator: WakeCoordinator
    private(set) var hooksInstalled = false
    private(set) var hooksError: String?
    private(set) var launchAtLogin = false
    /// Bumped while a manual timer runs so that "time left" in the menu stays current.
    private var clockTick = Date()

    @ObservationIgnored private let server = IPCServer()
    @ObservationIgnored private let notifier = Notifier()
    @ObservationIgnored private let completion: CompletionRunner
    @ObservationIgnored private static let settingsKey = "wakeSettings"

    init() {
        let settings = Self.loadSettings()
        coordinator = WakeCoordinator(settings: settings, assertions: IOKitSleepAssertions())
        completion = CompletionRunner(coordinator: coordinator)
        if settings.notifyOnFinish || settings.notifyOnAttention { notifier.requestAuthorization() }
        coordinator.onEffect = { [unowned self] effect in handle(effect) }
        let coordinator = coordinator
        do {
            try server.start { request in await coordinator.handle(request) }
        } catch {
            hooksError = String(localized: "IPC server failed: \(String(describing: error))")
        }
        refreshState()
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard let self else { return }
                if case .until = snapshot.manual { clockTick = Date() }
            }
        }
    }

    // MARK: - Presentation

    var snapshot: WakeSnapshot { coordinator.snapshot }
    var settings: WakeSettings { coordinator.settings }

    var symbolName: String {
        let s = snapshot
        if s.workingCount > 0 { return "sparkles" }
        if s.manual != .off || s.prevention != .none { return "cup.and.saucer.fill" }
        if s.waitingCount > 0 { return "hourglass" }
        return "moon.zzz"
    }

    var statusTitle: String {
        let s = snapshot
        if s.workingCount > 0 {
            return s.workingCount == 1
                ? String(localized: "Claude Code is working")
                : String(localized: "\(s.workingCount) Claude Code sessions working")
        }
        switch s.manual {
        case .indefinite: return String(localized: "Keeping Mac awake")
        case .until(let end):
            return String(localized: "Keeping Mac awake until \(Self.clock(end)) (\(remaining(until: end)) left)")
        case .off: break
        }
        if s.waitingCount > 0 { return String(localized: "Waiting for your input") }
        return String(localized: "Sleep allowed")
    }

    /// Extra line shown while agents are working, so a running manual timer does not disappear from view.
    var manualHoldLine: String? {
        guard snapshot.workingCount > 0 else { return nil }
        switch snapshot.manual {
        case .off: return nil
        case .indefinite: return String(localized: "Manual hold: on")
        case .until(let end):
            return String(localized: "Manual hold: until \(Self.clock(end)) (\(remaining(until: end)) left)")
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
              let settings = try? JSONDecoder().decode(WakeSettings.self, from: data) else {
            return WakeSettings()
        }
        return settings
    }
}
