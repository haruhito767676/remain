// Foundation-dependent helpers live here so that test files only need `import Testing`.
// (Importing both in one file requires the `_Testing_Foundation` overlay, which is missing
// from some Command Line Tools installs.)
import Foundation
@testable import RemainCore

let t0 = Date(timeIntervalSince1970: 1_000_000)

func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

func event(_ kind: AgentEvent.Kind, _ id: String = "a") -> AgentEvent {
    AgentEvent(sessionID: id, kind: kind)
}

func decodeHook(_ json: String) throws -> HookPayload {
    try JSONDecoder().decode(HookPayload.self, from: Data(json.utf8))
}

func makeInstaller(existing: String? = nil) throws -> HookInstaller {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("settings.json")
    if let existing { try existing.write(to: url, atomically: true, encoding: .utf8) }
    return HookInstaller(settingsURL: url, executablePath: "/Applications/remAIn.app/Contents/Helpers/remain")
}

func readSettings(_ installer: HookInstaller) throws -> [String: Any] {
    let data = try Data(contentsOf: installer.settingsURL)
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
}

func rawSettings(_ installer: HookInstaller) throws -> String {
    try String(contentsOf: installer.settingsURL, encoding: .utf8)
}

func decodeSettings(_ json: String) throws -> WakeSettings {
    try JSONDecoder().decode(WakeSettings.self, from: Data(json.utf8))
}

// MARK: - Liveness helpers

func scan(_ jsonLines: [String]) -> Bool {
    TranscriptScanner.containsInterruption(in: Data((jsonLines.joined(separator: "\n") + "\n").utf8))
}

func scanFile(_ text: String, from offset: UInt64 = 0) throws -> TranscriptScan {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
    try text.write(to: url, atomically: true, encoding: .utf8)
    return TranscriptScanner.scan(path: url.path, from: offset)
}

final class FakeAssertions: SleepAssertionProviding, @unchecked Sendable {
    private(set) var level: SleepPrevention = .none
    func apply(_ level: SleepPrevention) { self.level = level }
}

final class FakeProbe: SessionProbing, @unchecked Sendable {
    var alive = true
    var next = TranscriptScan(newOffset: 0, interrupted: false)
    func isAlive(pid: Int32) -> Bool { alive }
    func scanTranscript(path: String, from offset: UInt64) -> TranscriptScan { next }
}

func ownPID() -> Int32 { getpid() }
func parentPID() -> Int32 { getppid() }

// MARK: - Activity helpers

final class TestClock: @unchecked Sendable {
    var current = t0
    func advance(_ seconds: Double) { current = current.addingTimeInterval(seconds) }
}

final class MemoryActivityStore: ActivityStoring, @unchecked Sendable {
    var intervals: [HoldInterval] = []
    var open: OpenInterval?
    var rewrites = 0
    func load() -> [HoldInterval] { intervals }
    func append(_ interval: HoldInterval) { intervals.append(interval) }
    func rewrite(_ intervals: [HoldInterval]) { self.intervals = intervals; rewrites += 1 }
    func loadOpen() -> OpenInterval? { open }
    func saveOpen(_ open: OpenInterval?) { self.open = open }
}

func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    utcCalendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

func makeFileStore() -> (store: FileActivityStore, directory: URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    return (FileActivityStore(directory: directory), directory)
}

func appendGarbageLine(to directory: URL) throws {
    let url = directory.appendingPathComponent("activity.jsonl")
    let handle = try FileHandle(forWritingTo: url)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("{ this is not json\n".utf8))
    try handle.close()
}

func project(_ path: String) -> AgentEvent { AgentEvent(sessionID: "s", cwd: path, kind: .prompt) }

func openInterval(start: Double, lastSeen: Double, projects: Set<String> = ["remain"]) -> OpenInterval {
    OpenInterval(id: UUID(), start: at(start), sources: [.agent], projects: projects, lastSeen: at(lastSeen))
}

// MARK: - Lid helpers

final class FakeDisabler: SleepDisabling, @unchecked Sendable {
    var ready = true
    var succeeds = true
    private(set) var disabled = false
    private(set) var sleepNowCalls = 0
    private(set) var setCalls: [Bool] = []
    func isReady() -> Bool { ready }
    func setDisabled(_ disabled: Bool) -> Bool {
        setCalls.append(disabled)
        guard succeeds else { return false }
        self.disabled = disabled
        return true
    }
    func isDisabled() -> Bool { disabled }
    func sleepNow() { sleepNowCalls += 1 }
    func forceDisabled(_ value: Bool) { disabled = value }
}

final class FakeHeartbeat: HeartbeatWriting, @unchecked Sendable {
    private(set) var present = false
    private(set) var beats = 0
    func beat() { present = true; beats += 1 }
    func clear() { present = false }
    func exists() -> Bool { present }
    func plant() { present = true }
}

@MainActor
final class FakeLid: LidSleepControlling {
    private(set) var calls: [(prevent: Bool, lidClosed: Bool)] = []
    private(set) var shutdowns = 0
    func apply(prevent: Bool, lidClosed: Bool) { calls.append((prevent, lidClosed)) }
    func shutdown() { shutdowns += 1 }
}

/// Runs the real watchdog script with a throw-away HOME and returns the heartbeat path.
struct WatchdogRun {
    let home: URL
    var heartbeat: URL { home.appendingPathComponent("Library/Application Support/remAIn/lid-heartbeat") }

    init() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("remain-home-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: heartbeat.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    func plantHeartbeat(ageSeconds: Double) throws {
        try "x".write(to: heartbeat, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-ageSeconds)], ofItemAtPath: heartbeat.path)
    }

    var heartbeatExists: Bool { FileManager.default.fileExists(atPath: heartbeat.path) }

    @discardableResult
    func run() throws -> Int32 {
        let script = home.appendingPathComponent("watchdog.sh")
        try LidSupport.watchdogScript.write(to: script, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [script.path]
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    static func syntaxCheck() throws -> Int32 {
        let script = FileManager.default.temporaryDirectory.appendingPathComponent("wd-\(UUID().uuidString).sh")
        try LidSupport.watchdogScript.write(to: script, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-n", script.path]
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

func sudoersContent(for user: String) -> String? { LidSupport.sudoersContent(user: user) }
func watchdogPlistObject() throws -> [String: Any] {
    let support = LidSupport(supportDirectory: URL(fileURLWithPath: "/tmp/Application Support/remAIn"),
                             launchAgentsDirectory: URL(fileURLWithPath: "/tmp/LaunchAgents"), userName: "tester", uid: 501)
    let data = Data(support.watchdogPlist().utf8)
    return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
}
func adminScript(_ command: String) -> String { LidSupport.adminAppleScript(command) }

// MARK: - Multi-agent helpers

func decodeEvent(_ agent: AgentKind, _ event: String? = nil, _ json: String) -> AgentEvent? {
    HookDecoder.decode(agent: agent, eventName: event, stdin: Data(json.utf8))
}

func roundTrip(_ event: AgentEvent) throws -> AgentEvent {
    try JSONDecoder().decode(AgentEvent.self, from: JSONEncoder().encode(event))
}

func decodeInterval(_ json: String) throws -> HoldInterval {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(HoldInterval.self, from: Data(json.utf8))
}

func makeAntigravityInstaller(existing: String? = nil, executable: String = "/Applications/remAIn.app/Contents/Helpers/remain") throws -> AntigravityHookInstaller {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("hooks.json")
    if let existing { try existing.write(to: url, atomically: true, encoding: .utf8) }
    return AntigravityHookInstaller(configURL: url, executablePath: executable)
}

func readJSON(_ url: URL) throws -> [String: Any] {
    try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
}

func installerAt(_ path: String, existing: String? = nil) throws -> HookInstaller {
    let installer = try makeInstaller(existing: existing)
    return HookInstaller(settingsURL: installer.settingsURL, executablePath: path)
}
