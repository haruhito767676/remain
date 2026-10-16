import Foundation

/// Undoes everything remAIn has put on this Mac, except the app itself (moving that to the Trash is
/// the user's call). Every step is independent: a failure or a cancelled password prompt is reported
/// and the remaining steps still run.
public struct Uninstaller: Sendable {
    public struct Report: Equatable, Sendable {
        public var hooksRemoved: [AgentKind] = []
        public var lidSupportRemoved = false
        public var lidSupportSkipped = false // the administrator prompt was cancelled
        public var commandLineRemoved = false
        public var commandLineSkipped = false // the administrator prompt was cancelled
        public var dataRemoved: [String] = []
        public var errors: [String] = []
    }

    private let manager: IntegrationManager
    private let lid: LidSupport?
    private let commandLine: CommandLineTool?
    private let supportDirectory: URL

    /// - Parameter lid: pass `nil` to leave the lid-closed setup alone (tests, or a Mac that never set it up).
    public init(manager: IntegrationManager, lid: LidSupport? = LidSupport(), commandLine: CommandLineTool? = nil, supportDirectory: URL = RemainPaths.supportDirectory) {
        self.manager = manager
        self.lid = lid
        self.commandLine = commandLine
        self.supportDirectory = supportDirectory
    }

    /// Files remAIn writes in its support folder. The socket is left to the running app.
    static let dataFiles = [
        "activity.jsonl", "activity-open.json", "hook-debug.jsonl", "debug", "lid-heartbeat", "lid-watchdog.sh",
    ]

    public func removeEverything() -> Report {
        var report = Report()

        // 1. Hooks: only the entries remAIn wrote, in each tool that has them.
        for agent in AgentKind.integrable {
            if let problem = manager.configProblem(of: agent) {
                // Unreadable: not touched, but say so, because remAIn's entries may still be inside.
                report.errors.append("\(agent.displayName): \(problem). Left untouched; remove remAIn's hooks by hand if they are there.")
                continue
            }
            switch manager.state(of: agent) {
            case .installed, .needsRepair:
                do {
                    try manager.uninstall(agent)
                    report.hooksRemoved.append(agent)
                } catch {
                    report.errors.append("\(agent.displayName): \(error)")
                }
            case .notInstalled, .notDetected:
                break
            }
        }

        // 2. Lid-closed setup: make sure sleep is on again, then drop the sudo rule and the watchdog.
        if let lid, lid.isPrivilegeInstalled() || lid.isWatchdogLoaded() {
            _ = Shell.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "disablesleep", "0"]) // best effort
            do {
                try lid.tearDown()
                report.lidSupportRemoved = true
            } catch LidSupportError.cancelled {
                lid.removeWatchdog() // the part that needs no password still goes
                report.lidSupportSkipped = true
            } catch {
                report.errors.append("Lid-closed setup: \(error)")
            }
        }

        // 3. The `remain` command in Terminal: only our own link.
        if let commandLine, [.installed, .needsRepair].contains(commandLine.state()) {
            do {
                try commandLine.uninstall()
                report.commandLineRemoved = true
            } catch CommandLineToolError.cancelled {
                report.commandLineSkipped = true
            } catch {
                report.errors.append("Command-line tool: \(error)")
            }
        }

        // 4. Data: history, debug log, heartbeat and watchdog script.
        for name in Self.dataFiles {
            let url = supportDirectory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                try FileManager.default.removeItem(at: url)
                report.dataRemoved.append(name)
            } catch {
                report.errors.append("\(name): \(error.localizedDescription)")
            }
        }
        return report
    }
}
