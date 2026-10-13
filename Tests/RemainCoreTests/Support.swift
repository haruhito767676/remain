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
