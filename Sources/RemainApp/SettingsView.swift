import SwiftUI
import RemainCore

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Keep awake while Claude Code waits for me", isOn: Binding(
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
                    Text("5 minutes").tag(TimeInterval(5 * 60))
                    Text("15 minutes").tag(TimeInterval(15 * 60))
                    Text("30 minutes").tag(TimeInterval(30 * 60))
                    Text("1 hour").tag(TimeInterval(60 * 60))
                }
            } header: {
                Text("Agents")
            } footer: {
                Text("If a session stops reporting (for example after an interruption), remAIn lets the Mac sleep again after this time.")
            }

            Section {
                Toggle("Notify when a task finishes", isOn: Binding(
                    get: { model.settings.notifyOnFinish },
                    set: { value in
                        model.update { $0.notifyOnFinish = value }
                        if value { model.requestNotificationAuthorization() }
                    }
                ))
                Toggle("Notify when Claude Code needs my input", isOn: Binding(
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
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.refreshState() }
    }
}
