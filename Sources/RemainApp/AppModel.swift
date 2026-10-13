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

    @ObservationIgnored private let server = IPCServer()
    @ObservationIgnored private static let settingsKey = "wakeSettings"

    init() {
        let settings = Self.loadSettings()
        coordinator = WakeCoordinator(settings: settings, assertions: IOKitSleepAssertions())
        let coordinator = coordinator
        do {
            try server.start { request in await coordinator.handle(request) }
        } catch {
            hooksError = "IPC server failed: \(error)"
        }
        refreshState()
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
            return s.workingCount == 1 ? "Claude Code is working" : "\(s.workingCount) Claude Code sessions working"
        }
        switch s.manual {
        case .indefinite: return "Keeping Mac awake"
        case .until(let end): return "Keeping Mac awake until \(end.formatted(date: .omitted, time: .shortened))"
        case .off: break
        }
        if s.waitingCount > 0 { return "Waiting for your input" }
        return "Sleep allowed"
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

    func installHooks() { runInstaller { try $0.install() } }
    func uninstallHooks() { runInstaller { try $0.uninstall() } }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            hooksError = "Launch at login: \(error.localizedDescription)"
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
            hooksError = "Could not find the remain command-line helper."
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
