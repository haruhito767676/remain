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
                Picker("Stop holding after silence of", selection: Binding(
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
                Text("Interruptions and closed sessions are detected automatically. This timeout is only a safety net for a session that stops reporting for any other reason.")
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
                Text("remAIn resumes automatically once the condition clears. The battery limit resumes 5 points above the threshold.")
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
                Picker("Only for tasks longer than", selection: Binding(
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
                Text("The action runs 10 seconds after the last task ends, and is skipped if you start new work. The length filter applies to the action as well.")
            }

            Section {
                LabeledContent("Hooks") {
                    if model.hooksInstalled {
                        Button("Remove") { model.uninstallHooks() }
                    } else {
                        Button("Install") { model.installHooks() }
                    }
                }
                if let error = model.hooksError {
                    Text(error).foregroundStyle(.red)
                }
            } header: {
                Text("Claude Code")
            } footer: {
                Text("Adds remAIn to ~/.claude/settings.json so it knows when Claude Code starts and stops working. Works with the VS Code extension and the CLI.")
            }

            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsLayout.width, height: SettingsLayout.height)
        .onAppear { model.refreshState() }
    }
}
