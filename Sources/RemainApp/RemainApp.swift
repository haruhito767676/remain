import SwiftUI
import RemainCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon, also when launched outside an app bundle.
        NSApp.setActivationPolicy(.accessory)
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
            Image(systemName: model.symbolName)
        }

        Settings {
            SettingsView(model: model)
        }
    }
}
