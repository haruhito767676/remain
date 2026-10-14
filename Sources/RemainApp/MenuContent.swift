import SwiftUI
import RemainCore

/// Rendered by `MenuBarExtra` in its default `.menu` style, i.e. a real NSMenu.
struct MenuContent: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // Buttons rather than plain Text: a Text row is a disabled menu item and renders in a
        // low-contrast gray. A status row only does something when it describes a manual hold:
        // clicking that ends it.
        Button(model.statusTitle) {
            if model.statusIsManualHold { model.coordinator.setManual(.off) }
        }
        if model.needsAttention {
            Button("Finish setting up your agents…") {
                model.settingsTab = .general
                showSettings()
            }
        }
        if let line = model.manualHoldLine {
            Button(line) { model.coordinator.setManual(.off) }
        }

        Divider()

        // The checkmark shows which choice is active; the time left is in the status row above.
        Menu("Keep Awake") {
            keepAwakeChoice("Off", isOn: model.snapshot.manual == .off) { model.coordinator.setManual(.off) }
            Divider()
            keepAwakeChoice("30 Minutes", minutes: 30)
            keepAwakeChoice("1 Hour", minutes: 60)
            keepAwakeChoice("2 Hours", minutes: 120)
            keepAwakeChoice("4 Hours", minutes: 240)
            Divider()
            keepAwakeChoice("Indefinitely", isOn: model.snapshot.manual == .indefinite) {
                model.keepAwake(minutes: nil)
            }
        }

        if model.hasBattery {
            Toggle("Keep Running with Lid Closed", isOn: Binding(
                get: { model.settings.keepRunningWithLidClosed },
                set: { enabled in
                    model.setLidMode(enabled)
                    // Not set up yet: take the user to where the setup button is.
                    if enabled, !model.lidReady { showSettings() }
                }
            ))
        }

        Divider()

        Button("Settings…") {
            model.settingsTab = .general
            showSettings()
        }
        .keyboardShortcut(",")

        Button("About remAIn") { showAbout() }

        Button("Quit remAIn") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func keepAwakeChoice(_ title: LocalizedStringKey, minutes: Int) -> some View {
        keepAwakeChoice(title, isOn: model.isKeepingAwake(forMinutes: minutes)) { model.keepAwake(minutes: minutes) }
    }

    private func keepAwakeChoice(_ title: LocalizedStringKey, isOn: Bool, action: @escaping () -> Void) -> some View {
        Toggle(title, isOn: Binding(get: { isOn }, set: { _ in action() }))
    }

    private func showSettings() {
        NSApp.activate()
        openSettings()
    }

    /// The standard macOS About panel: name, icon and version come from the bundle.
    private func showAbout() {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let link = NSAttributedString(
            string: remainRepositoryURL,
            attributes: [.link: URL(string: remainRepositoryURL)!, .font: NSFont.systemFont(ofSize: 11), .paragraphStyle: centered]
        )
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: link])
    }
}
