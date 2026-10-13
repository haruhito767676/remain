import Foundation

// Keeping a MacBook running with its lid closed means turning off sleep system-wide
// (`pmset disablesleep 1`), which needs root. Because a Mac that never sleeps in a bag is a real
// hazard, this file is built around failing safe:
//
//  * the privilege is narrow: passwordless sudo for exactly `pmset disablesleep 0|1`;
//  * while sleep is disabled the app writes a heartbeat file every few seconds;
//  * a separate launchd agent (the watchdog) turns sleep back on if that heartbeat goes stale,
//    i.e. when the app crashed or was killed;
//  * on launch the app repairs a leftover state itself.

// MARK: - Abstractions

public protocol SleepDisabling: Sendable {
    /// Passwordless `pmset` is allowed and the watchdog is running.
    func isReady() -> Bool
    func setDisabled(_ disabled: Bool) -> Bool
    func isDisabled() -> Bool
    /// Put the Mac to sleep right now (needs no privileges).
    func sleepNow()
}

public protocol HeartbeatWriting: Sendable {
    func beat()
    func clear()
    func exists() -> Bool
}

public protocol LidSleepControlling: AnyObject {
    @MainActor func apply(prevent: Bool, lidClosed: Bool)
    @MainActor func shutdown()
}

public enum LidFailure: Equatable, Sendable {
    case notSetUp
    case commandFailed
}

// MARK: - Controller

/// Engages and releases "do not sleep when the lid closes" on request of the coordinator.
@MainActor
public final class LidSleepController: LidSleepControlling {
    public private(set) var engaged = false
    public var onFailure: ((LidFailure) -> Void)?

    private let disabler: any SleepDisabling
    private let heartbeat: any HeartbeatWriting
    private let heartbeatInterval: Duration
    private var heartbeatTask: Task<Void, Never>?
    private let now: @Sendable () -> Date
    private let retryInterval: TimeInterval
    private var lastFailureAt: Date?

    public init(
        disabler: any SleepDisabling, heartbeat: any HeartbeatWriting,
        heartbeatInterval: Duration = .seconds(10), retryInterval: TimeInterval = 30,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.disabler = disabler
        self.heartbeat = heartbeat
        self.heartbeatInterval = heartbeatInterval
        self.retryInterval = retryInterval
        self.now = now
    }

    /// Repairs a leftover from a previous run that did not shut down cleanly.
    /// Only acts if our heartbeat file exists, so a `disablesleep` the user set themselves is left alone.
    public func recoverOnLaunch() {
        guard heartbeat.exists() else { return }
        _ = disabler.setDisabled(false)
        heartbeat.clear()
    }

    public func apply(prevent: Bool, lidClosed: Bool) {
        if prevent, !engaged {
            engage()
        } else if !prevent, engaged {
            release(lidClosed: lidClosed)
        }
    }

    public func shutdown() {
        guard engaged else { return }
        release(lidClosed: false)
    }

    private func engage() {
        // Every agent event triggers a refresh; do not hammer a broken setup or repeat the complaint.
        if let failedAt = lastFailureAt, now().timeIntervalSince(failedAt) < retryInterval { return }
        guard disabler.isReady() else {
            lastFailureAt = now()
            onFailure?(.notSetUp)
            return
        }
        // Heartbeat first: if anything goes wrong after this point the watchdog can clean up.
        heartbeat.beat()
        guard disabler.setDisabled(true) else {
            heartbeat.clear()
            lastFailureAt = now()
            onFailure?(.commandFailed)
            return
        }
        lastFailureAt = nil
        engaged = true
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self, heartbeat, heartbeatInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: heartbeatInterval)
                guard self != nil else { return }
                heartbeat.beat()
            }
        }
    }

    private func release(lidClosed: Bool) {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        engaged = false
        _ = disabler.setDisabled(false)
        heartbeat.clear()
        // With the lid closed nothing else would trigger sleep now that the hold is over.
        if lidClosed { disabler.sleepNow() }
    }
}

// MARK: - Heartbeat file

public struct FileHeartbeat: HeartbeatWriting {
    private let url: URL

    public init(url: URL = RemainPaths.supportDirectory.appendingPathComponent("lid-heartbeat")) {
        self.url = url
    }

    public func beat() {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? String(Date().timeIntervalSince1970).write(to: url, atomically: true, encoding: .utf8)
    }

    public func clear() { try? FileManager.default.removeItem(at: url) }
    public func exists() -> Bool { FileManager.default.fileExists(atPath: url.path) }
}

// MARK: - Shell

enum Shell {
    /// Runs a command and returns its exit status and combined output.
    @discardableResult
    static func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}

// MARK: - The real thing

public struct PmsetSleepDisabler: SleepDisabling {
    private let support: LidSupport

    public init(support: LidSupport = LidSupport()) {
        self.support = support
    }

    public func isReady() -> Bool { support.isReady() }

    public func setDisabled(_ disabled: Bool) -> Bool {
        let result = Shell.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "disablesleep", disabled ? "1" : "0"])
        return result.status == 0 && isDisabled() == disabled
    }

    public func isDisabled() -> Bool {
        let output = Shell.run("/usr/bin/pmset", ["-g"]).output
        return output.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
    }

    public func sleepNow() {
        Shell.run("/usr/bin/pmset", ["sleepnow"])
    }
}

// MARK: - Setup: sudoers rule and watchdog

public enum LidSupportError: Error, CustomStringConvertible, Equatable {
    case cancelled
    case unsafeUserName
    case failed(String)

    public var description: String {
        switch self {
        case .cancelled: "Setup was cancelled."
        case .unsafeUserName: "The account name contains unexpected characters."
        case .failed(let message): message
        }
    }
}

public struct LidSupport: Sendable {
    public static let sudoersPath = "/etc/sudoers.d/remain"
    public static let agentLabel = "dev.remain.lid-watchdog"

    private let supportDirectory: URL
    private let launchAgentsDirectory: URL
    private let userName: String
    private let uid: uid_t

    public init(
        supportDirectory: URL = RemainPaths.supportDirectory,
        launchAgentsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
        userName: String = NSUserName(),
        uid: uid_t = getuid()
    ) {
        self.supportDirectory = supportDirectory
        self.launchAgentsDirectory = launchAgentsDirectory
        self.userName = userName
        self.uid = uid
    }

    var scriptURL: URL { supportDirectory.appendingPathComponent("lid-watchdog.sh") }
    var plistURL: URL { launchAgentsDirectory.appendingPathComponent("\(Self.agentLabel).plist") }

    // MARK: Content (pure, tested)

    /// Passwordless sudo for exactly the two `pmset disablesleep` commands, nothing else.
    static func sudoersContent(user: String) -> String? {
        guard !user.isEmpty, user.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }) else { return nil }
        return """
        # Installed by remAIn: lets it turn sleep off/on while an agent works with the lid closed.
        \(user) ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, /usr/bin/pmset disablesleep 1

        """
    }

    /// Re-enables sleep when the app stopped refreshing its heartbeat. Acts only if the heartbeat
    /// file exists, so a `disablesleep` the user set by hand is never touched.
    static let watchdogScript = """
    #!/bin/sh
    HB="$HOME/Library/Application Support/remAIn/lid-heartbeat"
    [ -f "$HB" ] || exit 0
    now=$(/bin/date +%s)
    modified=$(/usr/bin/stat -f %m "$HB" 2>/dev/null || echo 0)
    if [ $((now - modified)) -gt 45 ]; then
        /usr/bin/sudo -n /usr/bin/pmset disablesleep 0
        /bin/rm -f "$HB"
    fi

    """

    func watchdogPlist() -> String {
        func escape(_ text: String) -> String {
            text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        }
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(Self.agentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/sh</string>
                <string>\(escape(scriptURL.path))</string>
            </array>
            <key>StartInterval</key><integer>15</integer>
            <key>RunAtLoad</key><true/>
        </dict>
        </plist>

        """
    }

    /// Wraps a shell command for `osascript` so that macOS asks for an administrator password.
    static func adminAppleScript(_ command: String) -> String {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(escaped)\" with administrator privileges"
    }

    // MARK: State

    public func isPrivilegeInstalled() -> Bool {
        Shell.run("/usr/bin/sudo", ["-n", "-l", "/usr/bin/pmset", "disablesleep", "0"]).status == 0
    }

    public func isWatchdogLoaded() -> Bool {
        Shell.run("/bin/launchctl", ["print", "gui/\(uid)/\(Self.agentLabel)"]).status == 0
    }

    /// Both parts are required: running without the watchdog would remove the safety net.
    public func isReady() -> Bool { isPrivilegeInstalled() && isWatchdogLoaded() }

    // MARK: Actions

    public func setUp() throws {
        try installPrivilege()
        try installWatchdog()
    }

    public func tearDown() throws {
        removeWatchdog()
        try removePrivilege()
    }

    /// Needs the user's administrator password (macOS shows its own dialog).
    public func installPrivilege() throws {
        guard let content = Self.sudoersContent(user: userName) else { throw LidSupportError.unsafeUserName }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("remain-sudoers-\(UUID().uuidString)")
        try content.write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }
        // visudo validates the file first: a broken sudoers file could lock the user out of sudo.
        try runAsAdmin("/usr/sbin/visudo -cf '\(temp.path)' && /usr/bin/install -m 0440 -o root -g wheel '\(temp.path)' \(Self.sudoersPath)")
    }

    public func removePrivilege() throws {
        guard FileManager.default.fileExists(atPath: Self.sudoersPath) || isPrivilegeInstalled() else { return }
        try runAsAdmin("/bin/rm -f \(Self.sudoersPath)")
    }

    public func installWatchdog() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: supportDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)
        try Self.watchdogScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        try watchdogPlist().write(to: plistURL, atomically: true, encoding: .utf8)
        Shell.run("/bin/launchctl", ["bootout", "gui/\(uid)/\(Self.agentLabel)"]) // ignore: may not be loaded
        let result = Shell.run("/bin/launchctl", ["bootstrap", "gui/\(uid)", plistURL.path])
        guard result.status == 0 else { throw LidSupportError.failed("Could not start the watchdog: \(result.output)") }
    }

    public func removeWatchdog() {
        Shell.run("/bin/launchctl", ["bootout", "gui/\(uid)/\(Self.agentLabel)"])
        try? FileManager.default.removeItem(at: plistURL)
        try? FileManager.default.removeItem(at: scriptURL)
    }

    private func runAsAdmin(_ command: String) throws {
        let result = Shell.run("/usr/bin/osascript", ["-e", Self.adminAppleScript(command)])
        guard result.status == 0 else {
            if result.output.contains("-128") || result.output.localizedCaseInsensitiveContains("canceled") {
                throw LidSupportError.cancelled
            }
            throw LidSupportError.failed(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
