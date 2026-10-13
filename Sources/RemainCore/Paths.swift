import Foundation

public enum RemainPaths {
    public static var supportDirectory: URL {
        FileManager.default
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
