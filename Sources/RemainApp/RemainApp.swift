import SwiftUI
import RemainCore

/// SwiftUI only hands out "open Settings" to views, so the always-alive menu bar icon stores it here
/// for the app delegate to use.
@MainActor
enum SettingsOpener {
    static var open: (() -> Void)?

    /// Brings Settings to the front *and* makes it the key window. A menu bar app is not the active
    /// app, and without this the window appears dimmed behind whatever was in front.
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        open?()
        DispatchQueue.main.async {
            let window = NSApp.windows.first { $0.isVisible && $0.identifier?.rawValue.localizedCaseInsensitiveContains("settings") == true }
            window?.makeKeyAndOrderFront(nil)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon, also when launched outside an app bundle.
        NSApp.setActivationPolicy(.accessory)
    }

    /// Opening the app again while it runs (Finder, Spotlight, `open`) shows Settings. A menu bar icon
    /// can be pushed out of sight by the notch or a crowded menu bar, and this is the way back in.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsOpener.show()
        return false
    }
}

/// The menu bar icon. Besides drawing it, it captures the Settings action (see `SettingsOpener`).
private struct MenuBarIcon: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    /// The widest symbol we draw (the battery) at menu bar size.
    private static let slotWidth: CGFloat = 22

    var body: some View {
        Image(systemName: model.symbolName)
            // The symbols differ in width (the cup and the battery are wider than the moon); one
            // fixed, centred width keeps the icon from shifting when it changes.
            .frame(width: Self.slotWidth)
            // VoiceOver would otherwise read the symbol's generic name ("sparkles", "moon").
            .accessibilityLabel("remAIn: \(model.statusTitle)")
            .onAppear { SettingsOpener.open = { openSettings() } }
    }
}

@main
struct RemainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel

    init() {
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            MenuBarIcon(model: model)
        }

        Settings {
            SettingsView(model: model)
        }
    }
}
