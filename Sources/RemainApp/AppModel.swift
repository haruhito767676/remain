import SwiftUI
import ServiceManagement
import RemainCore

@MainActor
@Observable
final class AppModel {
    let coordinator: WakeCoordinator
    let activity: ActivityLog
    var settingsTab: SettingsTab = .general
    private(set) var integrations: [AgentKind: IntegrationState] = [:]
    private(set) var integrationError: String?
    private(set) var resetBusy = false
    private(set) var resetSummary: String?
    @ObservationIgnored var welcomeWindow: NSWindow?
    /// The welcome window's "Open at login" choice (on by default), applied when the window closes.
    var welcomeOpenAtLogin = true
    @ObservationIgnored private static let onboardingKey = "onboardingDone"
    private(set) var launchAtLogin = false
    private(set) var lidReady = false
    private(set) var lidBusy = false
    private(set) var lidError: String?
    /// Bumped while a manual timer runs so that "time left" in the menu stays current.
    private var clockTick = Date()

    @ObservationIgnored private let server = IPCServer()
    @ObservationIgnored private let notifier = Notifier()
    @ObservationIgnored private let completion: CompletionRunner
    @ObservationIgnored private let powerMonitor = SystemPowerMonitor()
    @ObservationIgnored private let lidSupport = LidSupport()
    @ObservationIgnored private let lidController: LidSleepController
    @ObservationIgnored private var lastLidFailureNotice: Date?
    @ObservationIgnored private static let lidRiskKey = "lidRiskAcknowledged"
    @ObservationIgnored private static let settingsKey = "wakeSettings"

    init() {
        let settings = Self.loadSettings()
        let activity = ActivityLog(store: FileActivityStore())
        self.activity = activity
        coordinator = WakeCoordinator(settings: settings, assertions: IOKitSleepAssertions(), activity: activity)
        lidController = LidSleepController(disabler: PmsetSleepDisabler(support: lidSupport), heartbeat: FileHeartbeat())
        lidController.recoverOnLaunch() // a crash may have left sleep disabled
        completion = CompletionRunner(coordinator: coordinator)
        coordinator.lid = lidController
        lidController.onFailure = { [unowned self] failure in lidFailed(failure) }
        powerMonitor.watchesLid = settings.keepRunningWithLidClosed
        if settings.notifyOnFinish || settings.notifyOnAttention { notifier.requestAuthorization() }
        coordinator.onEffect = { [unowned self] effect in handle(effect) }
        let coordinator = coordinator
        do {
            try server.start { request in await coordinator.handle(request) }
        } catch {
            integrationError = String(localized: "Could not start receiving hook events: \(String(describing: error))")
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [coordinator] _ in
            MainActor.assumeIsolated { coordinator.shutdown() }
        }
        powerMonitor.onChange = { [coordinator] state in coordinator.update(power: state) }
        powerMonitor.start()
        refreshState()
        repairIntegrationsIfBundled()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1)) // let the app finish launching before showing a window
            self?.showWelcomeIfNeeded()
        }
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

    /// Shown while the Mac would keep running with its lid closed.
    var lidLine: String? {
        snapshot.preventLidSleep ? String(localized: "Keeps running if you close the lid") : nil
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
        powerMonitor.watchesLid = new.keepRunningWithLidClosed
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
        case .lidLimitReached:
            notifier.lidLimitReached()
        }
    }

    func requestNotificationAuthorization() { notifier.requestAuthorization() }

    // MARK: - Reset

    /// Takes back everything remAIn put on the Mac (hooks, lid permission, login item, saved settings,
    /// history) and returns the app to its first-launch state. The app itself stays.
    func resetEverything() {
        guard !resetBusy, let manager = integrationManager() else { return }
        resetBusy = true
        resetSummary = nil
        update { $0.keepRunningWithLidClosed = false } // stop holding before the setup is taken away
        let lidSupport = lidSupport
        Task {
            let report = await Task.detached {
                Uninstaller(manager: manager, lid: lidSupport).removeEverything()
            }.value
            finishReset(report)
        }
    }

    private func finishReset(_ report: Uninstaller.Report) {
        // What only the app can undo: the login item and its saved settings.
        if SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister() }
        if let id = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: id) }
        // Defaults gone on disk; bring the running app in line (without writing them back).
        coordinator.update(settings: WakeSettings())
        powerMonitor.watchesLid = false
        activity.clear()
        welcomeOpenAtLogin = true

        var lines = [String(localized: "Reset done.")]
        if report.lidSupportSkipped { lines.append(String(localized: "The lid-closed permission was kept: the password prompt was cancelled.")) }
        lines.append(contentsOf: report.errors)
        resetSummary = lines.joined(separator: "\n")
        resetBusy = false
        refreshState()
    }

    // MARK: - Lid-closed mode

    /// The menu / settings switch. Turning it on requires the one-time system setup and an informed yes.
    func setLidMode(_ enabled: Bool) {
        guard enabled else {
            update { $0.keepRunningWithLidClosed = false }
            return
        }
        refreshState()
        guard lidReady else {
            settingsTab = .general
            lidError = String(localized: "Set up the system permission first.")
            return
        }
        guard confirmLidRisk() else { return }
        lidError = nil
        update { $0.keepRunningWithLidClosed = true }
    }

    /// Asks for the administrator password (macOS shows the dialog) off the main thread.
    func setUpLidSupport() {
        runLidSetup { try $0.setUp() }
    }

    func removeLidSupport() {
        update { $0.keepRunningWithLidClosed = false }
        runLidSetup { try $0.tearDown() }
    }

    private func runLidSetup(_ action: @escaping @Sendable (LidSupport) throws -> Void) {
        guard !lidBusy else { return }
        lidBusy = true
        lidError = nil
        let support = lidSupport
        Task {
            let result = await Task.detached { Result { try action(support) } }.value
            lidBusy = false
            if case .failure(let error) = result, error as? LidSupportError != .cancelled {
                lidError = String(localized: "Setup failed: \(String(describing: error))")
            }
            refreshState()
        }
    }

    private func confirmLidRisk() -> Bool {
        if UserDefaults.standard.bool(forKey: Self.lidRiskKey) { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Keep running with the lid closed?")
        alert.informativeText = String(localized: "While an agent works, your Mac keeps running with the lid closed. Watch for heat and battery: it stops automatically on heat, low battery, the time limit, or when the work finishes.")
        alert.addButton(withTitle: String(localized: "Turn On"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        UserDefaults.standard.set(true, forKey: Self.lidRiskKey)
        return true
    }

    private func lidFailed(_ failure: LidFailure) {
        if let last = lastLidFailureNotice, Date().timeIntervalSince(last) < 300 { return }
        lastLidFailureNotice = Date()
        notifier.lidFailed(failure)
    }

    // MARK: - Integrations

    /// Hooks are (re)written for `agent`; "Repair" is the same operation as "Install".
    func installIntegration(_ agent: AgentKind) { runIntegration { try $0.install(agent) } }
    func removeIntegration(_ agent: AgentKind) { runIntegration { try $0.uninstall(agent) } }

    /// A tool that is on this Mac but not connected, or connected to a stale path.
    var needsAttention: Bool {
        AgentKind.integrable.contains { integrations[$0] == .notInstalled || integrations[$0] == .needsRepair }
    }

    /// Only the tools that are on this Mac (or already connected). With none found, list them all so
    /// the section is never empty.
    var visibleIntegrations: [AgentKind] {
        let present = AgentKind.integrable.filter { integrations[$0] != .notDetected }
        return present.isEmpty ? AgentKind.integrable : present
    }

    /// The hooks remAIn wrote point at this app's helper. If the app moved, they quietly stop working,
    /// so fix our own entries. Skipped when run from a build folder, which must not hijack the hooks.
    private func repairIntegrationsIfBundled() {
        guard Bundle.main.bundleIdentifier != nil, let manager = integrationManager() else { return }
        if !manager.repairAll().isEmpty { refreshState() }
    }

    /// Shown once, on the very first launch, so a new user always gets to connect their tools and to
    /// decide about starting at login (hooks do nothing while the app is not running).
    func showWelcomeIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.onboardingKey) else { return }
        showWelcome()
    }

    func showWelcome() {
        if let window = welcomeWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: WelcomeView(model: self)))
        window.title = "remAIn"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                UserDefaults.standard.set(true, forKey: Self.onboardingKey)
                guard let self else { return }
                self.welcomeWindow = nil
                // Whatever way the window was closed, honour the choice (only a real app can register).
                if Bundle.main.bundleIdentifier != nil, self.welcomeOpenAtLogin != self.launchAtLogin {
                    self.setLaunchAtLogin(self.welcomeOpenAtLogin)
                }
            }
        }
        welcomeWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            integrationError = String(localized: "Launch at login: \(error.localizedDescription)")
        }
        refreshState()
    }

    func refreshState() {
        if let manager = integrationManager() {
            integrations = Dictionary(uniqueKeysWithValues: AgentKind.integrable.map { ($0, manager.state(of: $0)) })
        }
        lidReady = lidSupport.isReady()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Private

    private func runIntegration(_ action: (IntegrationManager) throws -> Void) {
        guard let manager = integrationManager() else {
            integrationError = String(localized: "Could not find the remain command-line helper.")
            return
        }
        do {
            try action(manager)
            integrationError = nil
        } catch {
            integrationError = "\(error)"
        }
        refreshState()
    }

    /// The CLI lives in `remAIn.app/Contents/Helpers/remain`, or next to the binary during development.
    private func integrationManager() -> IntegrationManager? {
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/remain"),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("remain"),
        ].compactMap { $0 }
        guard let cli = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            return nil
        }
        return IntegrationManager(executablePath: cli.path)
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
