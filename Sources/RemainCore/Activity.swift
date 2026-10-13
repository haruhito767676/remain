import Foundation
import Observation

// MARK: - Model

public enum HoldSource: String, Codable, Sendable {
    case agent
    case manual
}

public enum HoldEndReason: String, Codable, Sendable {
    case finished        // the agent reported Stop / SessionEnd
    case interrupted     // the user interrupted the agent
    case processExited   // the Claude Code process went away
    case timedOut        // the silence safety net fired
    case released        // switched off by hand
    case timerElapsed    // a manual timer ran out
    case powerGuard      // battery / thermal protection
    case appQuit         // remAIn was quit
    case appStopped      // remAIn stopped without closing the interval (crash, kill)
}

/// One stretch of time during which remAIn kept the Mac awake.
public struct HoldInterval: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var start: Date
    public var end: Date
    public var sources: Set<HoldSource>
    /// Folder names only, never full paths.
    public var projects: Set<String>
    public var endReason: HoldEndReason

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public init(id: UUID = UUID(), start: Date, end: Date, sources: Set<HoldSource>, projects: Set<String>, endReason: HoldEndReason) {
        self.id = id
        self.start = start
        self.end = end
        self.sources = sources
        self.projects = projects
        self.endReason = endReason
    }
}

/// The interval that is currently running. Persisted so a crash does not lose it.
public struct OpenInterval: Codable, Equatable, Sendable {
    public var id: UUID
    public var start: Date
    public var sources: Set<HoldSource>
    public var projects: Set<String>
    public var lastSeen: Date
}

// MARK: - Storage

public protocol ActivityStoring: Sendable {
    func load() -> [HoldInterval]
    func append(_ interval: HoldInterval)
    func rewrite(_ intervals: [HoldInterval])
    func loadOpen() -> OpenInterval?
    func saveOpen(_ open: OpenInterval?)
}

/// JSON Lines on disk: append-only, human-readable, and a damaged line costs one interval, not the file.
public struct FileActivityStore: ActivityStoring {
    private let logURL: URL
    private let openURL: URL

    public init(directory: URL = RemainPaths.supportDirectory) {
        logURL = directory.appendingPathComponent("activity.jsonl")
        openURL = directory.appendingPathComponent("activity-open.json")
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public func load() -> [HoldInterval] {
        guard let data = try? Data(contentsOf: logURL) else { return [] }
        return data.split(separator: UInt8(ascii: "\n")).compactMap { try? decoder.decode(HoldInterval.self, from: Data($0)) }
    }

    public func append(_ interval: HoldInterval) {
        guard var line = try? encoder.encode(interval) else { return }
        line.append(UInt8(ascii: "\n"))
        prepareDirectory()
        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: logURL)
        }
    }

    public func rewrite(_ intervals: [HoldInterval]) {
        prepareDirectory()
        var data = Data()
        for interval in intervals {
            if let line = try? encoder.encode(interval) { data.append(line); data.append(UInt8(ascii: "\n")) }
        }
        try? data.write(to: logURL, options: .atomic)
    }

    public func loadOpen() -> OpenInterval? {
        guard let data = try? Data(contentsOf: openURL) else { return nil }
        return try? decoder.decode(OpenInterval.self, from: data)
    }

    public func saveOpen(_ open: OpenInterval?) {
        guard let open, let data = try? encoder.encode(open) else {
            try? FileManager.default.removeItem(at: openURL)
            return
        }
        prepareDirectory()
        try? data.write(to: openURL, options: .atomic)
    }

    private func prepareDirectory() {
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
}

// MARK: - Log

/// Keeps the history in memory (for the UI) and on disk.
@MainActor
@Observable
public final class ActivityLog {
    public private(set) var intervals: [HoldInterval]
    public private(set) var open: OpenInterval?

    @ObservationIgnored private let store: any ActivityStoring

    public init(
        store: any ActivityStoring,
        retentionDays: Int = 90,
        now: @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        var loaded = store.load()

        // The app stopped without closing its last interval: close it at the last heartbeat.
        if let stale = store.loadOpen() {
            let recovered = HoldInterval(
                id: stale.id, start: stale.start, end: max(stale.lastSeen, stale.start),
                sources: stale.sources, projects: stale.projects, endReason: .appStopped
            )
            store.append(recovered)
            store.saveOpen(nil)
            loaded.append(recovered)
        }

        let cutoff = now().addingTimeInterval(-TimeInterval(retentionDays) * 86_400)
        let kept = loaded.filter { $0.end >= cutoff }
        if kept.count != loaded.count { store.rewrite(kept) }
        intervals = kept
    }

    public func begin(at time: Date, sources: Set<HoldSource>, projects: Set<String>) {
        let interval = OpenInterval(id: UUID(), start: time, sources: sources, projects: projects, lastSeen: time)
        open = interval
        store.saveOpen(interval)
    }

    /// Sources and projects only ever grow during an interval.
    public func update(at time: Date, sources: Set<HoldSource>, projects: Set<String>) {
        guard var current = open else { return }
        let grew = !sources.isSubset(of: current.sources) || !projects.isSubset(of: current.projects)
        current.sources.formUnion(sources)
        current.projects.formUnion(projects)
        current.lastSeen = time
        open = current
        if grew { store.saveOpen(current) }
    }

    public func heartbeat(at time: Date) {
        guard var current = open else { return }
        current.lastSeen = time
        open = current
        store.saveOpen(current)
    }

    public func end(at time: Date, reason: HoldEndReason) {
        guard let current = open else { return }
        open = nil
        store.saveOpen(nil)
        guard time.timeIntervalSince(current.start) >= 1 else { return } // not worth recording
        let interval = HoldInterval(
            id: current.id, start: current.start, end: time,
            sources: current.sources, projects: current.projects, endReason: reason
        )
        store.append(interval)
        intervals.append(interval)
    }

    public func clear() {
        intervals = []
        store.rewrite([])
    }
}

// MARK: - Summaries

public struct DayTotal: Identifiable, Equatable, Sendable {
    public var day: Date
    public var agent: TimeInterval
    public var manual: TimeInterval
    public var id: Date { day }
    public var total: TimeInterval { agent + manual }
}

public struct ProjectTotal: Identifiable, Equatable, Sendable {
    public var name: String
    public var seconds: TimeInterval
    public var id: String { name }
}

/// Pure functions over intervals so they can be tested without a clock or a file.
public enum ActivitySummary {
    /// All intervals including the running one, which is treated as ending at `now`.
    public static func all(_ intervals: [HoldInterval], open: OpenInterval?, now: Date) -> [HoldInterval] {
        guard let open else { return intervals }
        let running = HoldInterval(
            id: open.id, start: open.start, end: max(now, open.start),
            sources: open.sources, projects: open.projects, endReason: .appStopped
        )
        return intervals + [running]
    }

    /// Per-day totals for the last `days` days ending today. An interval that spans midnight is split.
    /// Time counts as "agent" whenever an agent was part of the interval, otherwise "manual".
    public static func daily(_ intervals: [HoldInterval], now: Date, days: Int, calendar: Calendar = .current) -> [DayTotal] {
        let today = calendar.startOfDay(for: now)
        var totals: [Date: DayTotal] = [:]
        for offset in 0..<days {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            totals[day] = DayTotal(day: day, agent: 0, manual: 0)
        }
        for interval in intervals {
            var cursor = interval.start
            while cursor < interval.end {
                let day = calendar.startOfDay(for: cursor)
                let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
                let slice = min(interval.end, nextDay).timeIntervalSince(cursor)
                if var total = totals[day] {
                    if interval.sources.contains(.agent) { total.agent += slice } else { total.manual += slice }
                    totals[day] = total
                }
                cursor = nextDay
            }
        }
        return totals.values.sorted { $0.day < $1.day }
    }

    /// Time per project since `since`. An interval touching several projects is split evenly.
    public static func byProject(_ intervals: [HoldInterval], since: Date) -> [ProjectTotal] {
        var seconds: [String: TimeInterval] = [:]
        for interval in intervals where interval.end > since {
            let counted = interval.end.timeIntervalSince(max(interval.start, since))
            guard counted > 0, !interval.projects.isEmpty else { continue }
            for project in interval.projects { seconds[project, default: 0] += counted / Double(interval.projects.count) }
        }
        return seconds.map { ProjectTotal(name: $0.key, seconds: $0.value) }.sorted { $0.seconds > $1.seconds }
    }
}
