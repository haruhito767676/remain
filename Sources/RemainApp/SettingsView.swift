import SwiftUI
import RemainCore

enum SettingsLayout {
    /// Every tab uses the same size, so the window does not jump when switching tabs.
    /// Content taller than this scrolls inside the form.
    static let width: CGFloat = 460
    static let height: CGFloat = 620
}

enum SettingsTab: Hashable {
    case general
    case activity
}

/// The Settings window: a tab bar in the toolbar style System Settings uses.
struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView(selection: $model.settingsTab) {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            ActivityView(model: model)
                .tabItem { Label("Activity", systemImage: "chart.bar") }
                .tag(SettingsTab.activity)
        }
    }
}

struct GeneralSettingsView: View {
    let model: AppModel
    @State private var confirmingUninstall = false

    var body: some View {
        Form {
            Section {
                Toggle("Keep awake while an agent waits for me", isOn: Binding(
                    get: { model.settings.holdWhileWaiting },
                    set: { value in model.update { $0.holdWhileWaiting = value } }
                ))
                Toggle("Keep the display on", isOn: Binding(
                    get: { model.settings.keepDisplayOn },
                    set: { value in model.update { $0.keepDisplayOn = value } }
                ))
                Picker("Release automatically after no activity for", selection: Binding(
                    get: { model.settings.sessionTimeout },
                    set: { value in model.update { $0.sessionTimeout = value } }
                )) {
                    Text("30 minutes").tag(TimeInterval(30 * 60))
                    Text("1 hour").tag(TimeInterval(60 * 60))
                    Text("2 hours").tag(TimeInterval(2 * 60 * 60))
                    Text("4 hours").tag(TimeInterval(4 * 60 * 60))
                }
            } header: {
                Text("Agents")
            } footer: {
                Text("Interruptions and exits are detected automatically. This is only a safety net.")
            }

            Section {
                Picker("Let the Mac sleep when the battery is below", selection: Binding(
                    get: { model.settings.batteryCutoffPercent },
                    set: { value in model.update { $0.batteryCutoffPercent = value } }
                )) {
                    Text("Never").tag(0)
                    ForEach([10, 15, 20, 30], id: \.self) { Text(verbatim: "\($0)%").tag($0) }
                }
                Toggle("Only keep awake on AC power", isOn: Binding(
                    get: { model.settings.holdOnlyOnAC },
                    set: { value in model.update { $0.holdOnlyOnAC = value } }
                ))
                Toggle("Don't keep awake in Low Power Mode", isOn: Binding(
                    get: { model.settings.respectLowPowerMode },
                    set: { value in model.update { $0.respectLowPowerMode = value } }
                ))
                Toggle("Let the Mac sleep when it gets too hot", isOn: Binding(
                    get: { model.settings.releaseWhenOverheating },
                    set: { value in model.update { $0.releaseWhenOverheating = value } }
                ))
            } header: {
                Text("Power")
            } footer: {
                Text("It resumes automatically once the condition clears.")
            }

            Section {
                LabeledContent("System permission") {
                    HStack {
                        Text(model.lidReady ? "Ready" : "Not set up").foregroundStyle(.secondary)
                        if model.lidReady {
                            Button("Remove") { model.removeLidSupport() }.disabled(model.lidBusy)
                        } else {
                            Button("Set Up…") { model.setUpLidSupport() }.disabled(model.lidBusy)
                        }
                    }
                }
                Toggle("Keep running with the lid closed", isOn: Binding(
                    get: { model.settings.keepRunningWithLidClosed },
                    set: { model.setLidMode($0) }
                ))
                .disabled(!model.lidReady)
                Picker("Stop after", selection: Binding(
                    get: { model.settings.lidClosedLimit },
                    set: { value in model.update { $0.lidClosedLimit = value } }
                )) {
                    Text("1 hour").tag(TimeInterval(1 * 3600))
                    Text("2 hours").tag(TimeInterval(2 * 3600))
                    Text("3 hours").tag(TimeInterval(3 * 3600))
                    Text("4 hours").tag(TimeInterval(4 * 3600))
                    Text("6 hours").tag(TimeInterval(6 * 3600))
                }
                if let error = model.lidError {
                    Text(error).foregroundStyle(.red)
                }
            } header: {
                Text("Lid Closed")
            } footer: {
                Text("Asks for your password once.")
            }

            Section {
                Toggle("Notify when a task finishes", isOn: Binding(
                    get: { model.settings.notifyOnFinish },
                    set: { value in
                        model.update { $0.notifyOnFinish = value }
                        if value { model.requestNotificationAuthorization() }
                    }
                ))
                Toggle("Notify when an agent needs my input", isOn: Binding(
                    get: { model.settings.notifyOnAttention },
                    set: { value in
                        model.update { $0.notifyOnAttention = value }
                        if value { model.requestNotificationAuthorization() }
                    }
                ))
                Picker("Only for work that took longer than", selection: Binding(
                    get: { model.settings.minimumNotifiableDuration },
                    set: { value in model.update { $0.minimumNotifiableDuration = value } }
                )) {
                    Text("Any length").tag(TimeInterval(0))
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("1 minute").tag(TimeInterval(60))
                    Text("5 minutes").tag(TimeInterval(5 * 60))
                }
                Picker("When all tasks are done", selection: Binding(
                    get: { model.settings.completionAction },
                    set: { value in model.update { $0.completionAction = value } }
                )) {
                    Text("Do nothing").tag(CompletionAction.nothing)
                    Text("Turn the display off").tag(CompletionAction.turnDisplayOff)
                    Text("Put the Mac to sleep").tag(CompletionAction.sleepMac)
                }
            } header: {
                Text("When Agents Finish")
            } footer: {
                Text("Runs 10 seconds after the last task ends, unless you start new work.")
            }

            Section {
                ForEach(model.visibleIntegrations, id: \.self) { agent in
                    IntegrationRow(model: model, agent: agent)
                }
                if let error = model.integrationError {
                    Text(error).foregroundStyle(.red)
                }
            } header: {
                Text("Integrations")
            } footer: {
                Text("remAIn adds only its own entries to each tool's hooks, to know when work starts and stops.")
            }

            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }

            Section {
                Button("Remove All remAIn Changes…", role: .destructive) { confirmingUninstall = true }
                    .disabled(model.uninstallBusy)
                if let summary = model.uninstallSummary {
                    Text(summary).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Removes remAIn's hooks from your tools, the lid-closed permission, the login item, saved settings and history. Your other settings stay as they are. The app itself is left for you to move to the Trash.")
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsLayout.width, height: SettingsLayout.height)
        .onAppear { model.refreshState() }
        .confirmationDialog("Remove everything remAIn has set up?", isPresented: $confirmingUninstall, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { model.removeEverything() }
        } message: {
            Text("macOS may ask for your password to remove the lid-closed permission.")
        }
    }
}

/// One tool: its state and the button that fits it. Shared by Settings and the welcome window.
struct IntegrationRow: View {
    let model: AppModel
    let agent: AgentKind

    var body: some View {
        let state = model.integrations[agent] ?? .notDetected
        LabeledContent(agent.displayName) {
            HStack {
                Text(label(state))
                    .foregroundStyle(state == .needsRepair ? Color.orange : Color.secondary)
                switch state {
                case .installed:
                    Button("Remove") { model.removeIntegration(agent) }
                case .needsRepair:
                    Button("Repair") { model.installIntegration(agent) }
                case .notInstalled, .notDetected:
                    Button("Install") { model.installIntegration(agent) }
                }
            }
        }
    }

    private func label(_ state: IntegrationState) -> LocalizedStringKey {
        switch state {
        case .installed: "Installed"
        case .notInstalled: "Not installed"
        case .notDetected: "Not detected"
        case .needsRepair: "Needs repair"
        }
    }
}

/// Shown once at first launch when a supported tool is on the Mac but not connected yet.
struct WelcomeView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to remAIn").font(.title2.bold())
            Text("remAIn keeps your Mac awake while an AI agent is working, and lets it sleep when the work is done. Connect the tools you use:")
                .fixedSize(horizontal: false, vertical: true)
            Form {
                ForEach(model.visibleIntegrations, id: \.self) { agent in
                    IntegrationRow(model: model, agent: agent)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: CGFloat(model.visibleIntegrations.count) * 44 + 40)
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Open at login", isOn: $model.welcomeOpenAtLogin)
                Text("remAIn has to be running to notice your agents.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = model.integrationError {
                Text(error).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Done") { model.welcomeWindow?.close() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
