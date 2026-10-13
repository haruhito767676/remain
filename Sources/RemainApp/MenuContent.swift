import SwiftUI
import RemainCore

/// Rendered by `MenuBarExtra` in its default `.menu` style, i.e. a real NSMenu.
struct MenuContent: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // Buttons rather than plain Text: a Text row is a disabled menu item and renders in a
        // low-contrast gray. Clicking a status row opens Settings.
        Button(model.statusTitle, action: showSettings)
        if model.needsAttention {
            Button("Finish setting up your agents…") {
                model.settingsTab = .general
                showSettings()
            }
        }
        if let line = model.manualHoldLine {
            Button(line, action: showSettings)
        }
        if let lid = model.lidLine {
            Button(lid, action: showSettings)
        }
        if let today = model.todaySummary {
            Button(today) {
                model.settingsTab = .activity
                showSettings()
            }
        }

        Divider()

        Toggle("Keep Awake", isOn: Binding(
            get: { model.snapshot.manual != .off },
            set: { model.coordinator.setManual($0 ? .indefinite : .off) }
        ))

        Menu("Keep Awake For") {
            Button("30 Minutes") { model.coordinator.setManual(minutes: 30) }
            Button("1 Hour") { model.coordinator.setManual(minutes: 60) }
            Button("2 Hours") { model.coordinator.setManual(minutes: 120) }
            Button("4 Hours") { model.coordinator.setManual(minutes: 240) }
        }

        Toggle("Keep Running with Lid Closed", isOn: Binding(
            get: { model.settings.keepRunningWithLidClosed },
            set: { enabled in
                model.setLidMode(enabled)
                // Not set up yet: take the user to where the setup button is.
                if enabled, !model.lidReady { showSettings() }
            }
        ))

        Toggle("Keep Display On", isOn: Binding(
            get: { model.settings.keepDisplayOn },
            set: { value in model.update { $0.keepDisplayOn = value } }
        ))

        Divider()

        Button("Settings…") {
            model.settingsTab = .general
            showSettings()
        }
        .keyboardShortcut(",")

        Button("Quit remAIn") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func showSettings() {
        NSApp.activate()
        openSettings()
    }
}
