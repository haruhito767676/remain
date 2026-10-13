import SwiftUI
import RemainCore

/// SwiftUI only hands out "open Settings" to views, so the always-alive menu bar icon stores it here
/// for the app delegate to use.
@MainActor
enum SettingsOpener {
    static var open: (() -> Void)?
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
        NSApp.activate()
        SettingsOpener.open?()
        return false
    }
}

/// The menu bar icon. Besides drawing it, it captures the Settings action (see `SettingsOpener`).
private struct MenuBarIcon: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(systemName: model.symbolName)
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
