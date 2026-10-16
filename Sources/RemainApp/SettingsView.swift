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
    @State private var confirmingReset = false

    private var commandLineLabel: LocalizedStringKey {
        switch model.commandLineState {
        case .installed: "Installed"
        case .notInstalled: "Not installed"
        case .needsRepair: "Needs repair"
        case .blocked: "Another file is in the way"
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Keep awake while an agent is waiting", isOn: Binding(
                    get: { model.settings.holdWhileWaiting },
                    set: { value in model.update { $0.holdWhileWaiting = value } }
                ))
                Toggle("Keep the display on while preventing sleep", isOn: Binding(
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
                if model.notificationsDenied, model.settings.notifyOnFinish || model.settings.notifyOnAttention {
                    LabeledContent("Notifications are off in System Settings") {
                        Button("Open System Settings…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
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
            }

            Section {
                if model.hasBattery {
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
                }
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
            }

            if model.hasBattery {
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
            }

            Section {
                LabeledContent("Command line tool") {
                    HStack {
                        Text(commandLineLabel).foregroundStyle(model.commandLineState == .needsRepair ? Color.orange : Color.secondary)
                        switch model.commandLineState {
                        case .installed: Button("Remove") { model.removeCommandLine() }.disabled(model.commandLineBusy)
                        case .needsRepair: Button("Repair…") { model.installCommandLine() }.disabled(model.commandLineBusy)
                        case .notInstalled: Button("Install…") { model.installCommandLine() }.disabled(model.commandLineBusy)
                        case .blocked: EmptyView()
                        }
                    }
                }
                if let error = model.commandLineError {
                    Text(error).foregroundStyle(.red)
                }
            } header: {
                Text("Command Line")
            } footer: {
                Text("Adds the remain command to Terminal.")
            }

            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }

            Section {
                Button("Reset Settings…", role: .destructive) { confirmingReset = true }
                    .disabled(model.resetBusy)
                if let summary = model.resetSummary {
                    Text(summary).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsLayout.width, height: SettingsLayout.height)
        .onAppear { model.refreshState() }
        .confirmationDialog("Reset all settings?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { model.resetEverything() }
        } message: {
            Text("This deletes all settings, connections and history.")
        }
    }
}

/// One tool: its state and the button that fits it. Shared by Settings and the welcome window.
struct IntegrationRow: View {
    let model: AppModel
    let agent: AgentKind

    var body: some View {
        let state = model.integrations[agent] ?? .notDetected
        HStack {
            Toggle(isOn: Binding(
                get: { state == .installed || state == .needsRepair },
                set: { $0 ? model.installIntegration(agent) : model.removeIntegration(agent) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.displayName)
                    if let note = note(state) {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(state == .needsRepair ? Color.orange : Color.secondary)
                    }
                }
            }
            .disabled(state == .notDetected)
            if state == .needsRepair {
                Button("Repair") { model.installIntegration(agent) }
            }
        }
    }

    private func note(_ state: IntegrationState) -> LocalizedStringKey? {
        switch state {
        case .notDetected: "Not detected"
        case .needsRepair: "Needs repair"
        case .installed, .notInstalled: nil
        }
    }
}

/// Shown once at first launch when a supported tool is on the Mac but not connected yet.
struct WelcomeView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to remAIn").font(.title2.bold())
            Text("Detects AI agent activity and keeps your Mac from sleeping.\nChoose the tools to connect.")
                .fixedSize(horizontal: false, vertical: true)
            Form {
                Section {
                    ForEach(model.visibleIntegrations, id: \.self) { agent in
                        IntegrationRow(model: model, agent: agent)
                    }
                }
                Section {
                    Toggle("Open remAIn at login", isOn: $model.welcomeOpenAtLogin)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: CGFloat(model.visibleIntegrations.count) * 38 + 24 + 46)
            .padding(.top, -12)
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
