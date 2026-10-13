import SwiftUI
import Charts
import RemainCore

/// "Activity" tab: how long remAIn kept the Mac awake, per day and per project, plus recent history.
struct ActivityView: View {
    let model: AppModel
    @State private var confirmingClear = false

    var body: some View {
        let log = model.activity
        let now = model.now
        let intervals = ActivitySummary.all(log.intervals, open: log.open, now: now)
        let days = ActivitySummary.daily(intervals, now: now, days: 14)
        let calendar = Calendar.current
        let projects = Array(ActivitySummary.byProject(
            intervals, since: calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now))!
        ).prefix(5))

        Form {
            Section {
                LabeledContent("Today") { Text(Self.format(ActivitySummary.daily(intervals, now: now, days: 1).first?.total ?? 0)) }
                LabeledContent("Last 7 days") { Text(Self.format(days.suffix(7).reduce(0) { $0 + $1.total })) }
                LabeledContent("Last 30 days") {
                    Text(Self.format(ActivitySummary.daily(intervals, now: now, days: 30).reduce(0) { $0 + $1.total }))
                }
            }

            Section("Last 14 days") {
                chart(days)
            }

            Section("By Project (last 30 days)") {
                if projects.isEmpty {
                    Text("No activity yet. Run a task with an AI agent and it will show up here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(projects) { project in
                        LabeledContent(project.name) { Text(Self.format(project.seconds)) }
                    }
                }
            }

            if !log.intervals.isEmpty {
                Section("Recent") {
                    ForEach(log.intervals.suffix(6).reversed()) { interval in
                        LabeledContent {
                            VStack(alignment: .trailing) {
                                Text(Self.format(interval.duration))
                                Text(interval.endReason.title).font(.caption).foregroundStyle(.secondary)
                            }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(Self.name(of: interval))
                                Text(Self.range(of: interval) + Self.toolsSuffix(of: interval)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Clear Activity Log…", role: .destructive) { confirmingClear = true }
                    .disabled(log.intervals.isEmpty)
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsLayout.width, height: SettingsLayout.height)
        .confirmationDialog("Clear the activity log?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { log.clear() }
        } message: {
            Text("This deletes all recorded activity. It cannot be undone.")
        }
    }

    // MARK: - Pieces

    private func chart(_ days: [DayTotal]) -> some View {
        let agent = String(localized: "Agents")
        let manual = String(localized: "Manual")
        return Chart {
            ForEach(days) { day in
                BarMark(x: .value("Day", day.day, unit: .day), y: .value("Minutes", day.agent / 60))
                    .foregroundStyle(by: .value("Source", agent))
                BarMark(x: .value("Day", day.day, unit: .day), y: .value("Minutes", day.manual / 60))
                    .foregroundStyle(by: .value("Source", manual))
            }
        }
        .chartForegroundStyleScale([agent: Color.accentColor, manual: Color.secondary.opacity(0.45)])
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(values: .stride(by: Self.tickStep(for: days))) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text(verbatim: Self.axisLabel(minutes: Int(minutes)))
                    }
                }
            }
        }
        .frame(height: 150)
        .padding(.vertical, 4)
    }

    /// Gridline spacing in minutes, always a clean step on the clock (15 min, 30 min, 1 h, 2 h ...).
    private static func tickStep(for days: [DayTotal]) -> Double {
        let peak = days.map { ($0.agent + $0.manual) / 60 }.max() ?? 0
        let steps: [Double] = [15, 30, 60, 120, 180, 360, 720]
        return steps.first { peak / $0 <= 4 } ?? 720
    }

    private static func axisLabel(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return "\(minutes / 60)h\(minutes % 60)m"
    }

    static func format(_ seconds: TimeInterval) -> String {
        if seconds < 1 { return "—" }
        if seconds < 60 { return String(localized: "Less than a minute") }
        return Duration.seconds(Int(seconds / 60) * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated, maximumUnitCount: 2))
    }

    private static func name(of interval: HoldInterval) -> String {
        if !interval.projects.isEmpty { return interval.projects.sorted().joined(separator: ", ") }
        // Some tools report no folder (Antigravity without an open workspace): name the tool instead.
        if !interval.agents.isEmpty { return interval.agents.map(\.displayName).sorted().joined(separator: ", ") }
        return interval.sources.contains(.agent) ? String(localized: "Agent") : String(localized: "Manual")
    }

    /// " · Antigravity" when tools are known and the title does not already say it.
    private static func toolsSuffix(of interval: HoldInterval) -> String {
        guard !interval.agents.isEmpty, !interval.projects.isEmpty else { return "" }
        return " · " + interval.agents.map(\.displayName).sorted().joined(separator: ", ")
    }

    private static func range(of interval: HoldInterval) -> String {
        interval.start.formatted(date: .abbreviated, time: .shortened) + " – " + interval.end.formatted(date: .omitted, time: .shortened)
    }
}

extension HoldEndReason {
    var title: String {
        switch self {
        case .finished: String(localized: "Finished")
        case .interrupted: String(localized: "Interrupted")
        case .processExited: String(localized: "Agent closed")
        case .timedOut: String(localized: "Timed out")
        case .released: String(localized: "Turned off")
        case .timerElapsed: String(localized: "Timer ended")
        case .powerGuard: String(localized: "Power guard")
        case .appQuit: String(localized: "remAIn quit")
        case .appStopped: String(localized: "remAIn stopped")
        }
    }
}
