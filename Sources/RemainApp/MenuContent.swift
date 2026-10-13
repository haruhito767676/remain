import SwiftUI
import RemainCore

/// Rendered by `MenuBarExtra` in its default `.menu` style, i.e. a real NSMenu.
struct MenuContent: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(model.statusTitle)

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

        Toggle("Keep Display On", isOn: Binding(
            get: { model.settings.keepDisplayOn },
            set: { value in model.update { $0.keepDisplayOn = value } }
        ))

        Divider()

        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Button("Quit remAIn") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
