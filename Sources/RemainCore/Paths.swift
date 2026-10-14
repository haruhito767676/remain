import Foundation

public enum RemainPaths {
    /// Where remAIn keeps its socket, history and lid-closed files. `REMAIN_SUPPORT_DIR` points it
    /// elsewhere, which is how screenshots and videos are made without touching the real history.
    public static var supportDirectory: URL {
        if let custom = ProcessInfo.processInfo.environment["REMAIN_SUPPORT_DIR"], !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("remAIn", isDirectory: true)
    }

    public static var socketPath: String {
        supportDirectory.appendingPathComponent("remain.sock").path
    }

    public static var claudeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }
}
