// Writes a believable month of activity history for screenshots and videos.
//
//   swift scripts/make-demo-data.swift /tmp/remain-demo
//   REMAIN_SUPPORT_DIR=/tmp/remain-demo build/remAIn.app/Contents/MacOS/RemainApp
//
// The data is invented (and deterministic): no real history is read or written.
import Foundation

struct Generator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: make-demo-data.swift <support-directory>\n".utf8))
    exit(1)
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

var rng = Generator(state: 20_260_714)
let calendar = Calendar.current
let now = Date()
let today = calendar.startOfDay(for: now)

let projects: [(String, Int)] = [("web-app", 40), ("api-server", 25), ("mobile-app", 14), ("docs-site", 12), ("dotfiles", 9)]
let agents: [(String, Int)] = [("claudeCode", 74), ("codex", 16), ("antigravity", 10)]
let endings: [(String, Int)] = [("finished", 68), ("interrupted", 14), ("processExited", 5), ("timedOut", 2), ("released", 11)]

func pick(_ table: [(String, Int)]) -> String {
    var roll = Int.random(in: 0..<table.reduce(0) { $0 + $1.1 }, using: &rng)
    for (name, weight) in table {
        if roll < weight { return name }
        roll -= weight
    }
    return table[0].0
}

let iso = ISO8601DateFormatter()
iso.formatOptions = [.withInternetDateTime]
func text(_ date: Date) -> String { iso.string(from: date) }

var lines: [String] = []
func add(start: Date, minutes: Int, sources: [String], projects: [String], agents: [String], reason: String) {
    let end = start.addingTimeInterval(TimeInterval(minutes * 60 + Int.random(in: 0..<60, using: &rng)))
    guard end < now else { return }
    let line = #"{"agents":[\#(agents.map { "\"\($0)\"" }.joined(separator: ","))],"end":"\#(text(end))","endReason":"\#(reason)","id":"\#(UUID().uuidString)","projects":[\#(projects.map { "\"\($0)\"" }.joined(separator: ","))],"sources":[\#(sources.map { "\"\($0)\"" }.joined(separator: ","))],"start":"\#(text(start))"}"#
    lines.append(line)
}

for offset in stride(from: 29, through: 0, by: -1) {
    let day = calendar.date(byAdding: .day, value: -offset, to: today)!
    let weekday = calendar.component(.weekday, from: day)
    let weekend = weekday == 1 || weekday == 7
    if weekend && Int.random(in: 0..<10, using: &rng) < 5 { continue } // some weekends off
    let count = weekend ? Int.random(in: 1...2, using: &rng) : Int.random(in: 3...6, using: &rng)
    var cursor = day.addingTimeInterval(TimeInterval(Int.random(in: 9 * 60 + 20...10 * 60 + 40, using: &rng) * 60))
    for _ in 0..<count {
        let minutes = weekend ? Int.random(in: 8...50, using: &rng) : Int.random(in: 6...95, using: &rng)
        if Int.random(in: 0..<10, using: &rng) == 0 {
            // A manual timer on its own.
            let length = [30, 60, 120].randomElement(using: &rng)!
            add(start: cursor, minutes: length, sources: ["manual"], projects: [], agents: [],
                reason: Bool.random(using: &rng) ? "timerElapsed" : "released")
            cursor = cursor.addingTimeInterval(TimeInterval((length + Int.random(in: 20...70, using: &rng)) * 60))
        } else {
            var chosen = [pick(projects)]
            if Int.random(in: 0..<8, using: &rng) == 0 { chosen.append(pick(projects)) }
            let tools = Set([pick(agents)])
            add(start: cursor, minutes: minutes, sources: ["agent"], projects: Array(Set(chosen)).sorted(),
                agents: tools.sorted(), reason: pick(endings))
            cursor = cursor.addingTimeInterval(TimeInterval((minutes + Int.random(in: 12...80, using: &rng)) * 60))
        }
        if cursor > day.addingTimeInterval(23 * 3600) { break }
    }
}

try (lines.joined(separator: "\n") + "\n").write(to: directory.appendingPathComponent("activity.jsonl"), atomically: true, encoding: .utf8)
print("Wrote \(lines.count) intervals to \(directory.path)/activity.jsonl")
