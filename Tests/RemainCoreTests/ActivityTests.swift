import Testing
@testable import RemainCore

private func interval(_ start: Double, _ end: Double, _ sources: Set<HoldSource> = [.agent], _ projects: Set<String> = ["remain"],
                      _ reason: HoldEndReason = .finished) -> HoldInterval {
    HoldInterval(start: at(start), end: at(end), sources: sources, projects: projects, endReason: reason)
}

@MainActor
@Suite struct ActivityLogTests {
    @Test func recordsAnIntervalFromBeginToEnd() {
        let store = MemoryActivityStore()
        let log = ActivityLog(store: store, now: { t0 })
        log.begin(at: at(0), sources: [.agent], projects: ["remain"])
        #expect(store.open != nil)
        log.end(at: at(90), reason: .finished)
        #expect(log.open == nil)
        #expect(store.open == nil)
        #expect(log.intervals.count == 1)
        #expect(log.intervals[0].duration == 90)
        #expect(store.intervals == log.intervals)
    }

    @Test func dropsIntervalsShorterThanASecond() {
        let log = ActivityLog(store: MemoryActivityStore(), now: { t0 })
        log.begin(at: at(0), sources: [.agent], projects: [])
        log.end(at: at(0.4), reason: .interrupted)
        #expect(log.intervals.isEmpty)
    }

    @Test func sourcesAndProjectsOnlyGrow() {
        let log = ActivityLog(store: MemoryActivityStore(), now: { t0 })
        log.begin(at: at(0), sources: [.manual], projects: [])
        log.update(at: at(5), sources: [.agent], projects: ["a"])
        log.update(at: at(9), sources: [], projects: ["b"])
        log.end(at: at(60), reason: .released)
        #expect(log.intervals[0].sources == [.manual, .agent])
        #expect(log.intervals[0].projects == ["a", "b"])
    }

    @Test func aCrashedIntervalIsRecoveredAtTheLastHeartbeat() {
        let store = MemoryActivityStore()
        store.open = openInterval(start: 0, lastSeen: 600)
        let log = ActivityLog(store: store, now: { at(700) })
        #expect(log.intervals.count == 1)
        #expect(log.intervals[0].end == at(600))
        #expect(log.intervals[0].endReason == .appStopped)
        #expect(store.open == nil)
        #expect(log.open == nil)
    }

    @Test func oldIntervalsAreDroppedAfterTheRetentionPeriod() {
        let store = MemoryActivityStore()
        store.intervals = [interval(-100 * 86_400, -100 * 86_400 + 60), interval(-10 * 86_400, -10 * 86_400 + 60)]
        let log = ActivityLog(store: store, retentionDays: 90, now: { t0 })
        #expect(log.intervals.count == 1)
        #expect(store.rewrites == 1)
    }

    @Test func clearEmptiesMemoryAndStore() {
        let store = MemoryActivityStore()
        store.intervals = [interval(0, 60)]
        let log = ActivityLog(store: store, now: { t0 })
        log.clear()
        #expect(log.intervals.isEmpty)
        #expect(store.intervals.isEmpty)
    }
}

@MainActor
@Suite struct ActivityCoordinatorTests {
    @MainActor
    private final class Rig {
        let clock = TestClock()
        let probe = FakeProbe()
        let log: ActivityLog
        let coordinator: WakeCoordinator

        init() {
            log = ActivityLog(store: MemoryActivityStore(), now: { t0 })
            let clock = clock
            coordinator = WakeCoordinator(
                assertions: FakeAssertions(), probe: probe, activity: log,
                pollInterval: .seconds(3600), now: { clock.current }
            )
        }
    }

    private func makeRig() -> Rig { Rig() }

    @Test func finishedAgentRunIsRecordedWithItsProject() {
        let rig = makeRig()
        rig.coordinator.receive(project("/Users/me/work/remain"))
        #expect(rig.log.open?.projects == ["remain"])
        rig.clock.advance(120)
        rig.coordinator.receive(event(.finish, "s"))
        #expect(rig.log.open == nil)
        #expect(rig.log.intervals.count == 1)
        let recorded = rig.log.intervals[0]
        #expect(recorded.duration == 120)
        #expect(recorded.sources == [.agent])
        #expect(recorded.projects == ["remain"])
        #expect(recorded.endReason == .finished)
    }

    @Test func fullPathsAreNeverStored() {
        let rig = makeRig()
        rig.coordinator.receive(project("/Users/secret-person/private/clients/acme"))
        rig.clock.advance(5)
        rig.coordinator.receive(event(.finish, "s"))
        #expect(rig.log.intervals[0].projects == ["acme"])
    }

    @Test func manualHoldIsRecordedAndReleased() {
        let rig = makeRig()
        rig.coordinator.setManual(.indefinite)
        rig.clock.advance(30)
        rig.coordinator.setManual(.off)
        #expect(rig.log.intervals.count == 1)
        #expect(rig.log.intervals[0].sources == [.manual])
        #expect(rig.log.intervals[0].endReason == .released)
    }

    @Test func manualTimerElapsing() {
        let rig = makeRig()
        rig.coordinator.setManual(minutes: 1)
        rig.clock.advance(61)
        rig.coordinator.update(settings: rig.coordinator.settings) // any refresh notices the expiry
        #expect(rig.log.intervals.first?.endReason == .timerElapsed)
    }

    @Test func silenceTimeout() {
        let rig = makeRig()
        rig.coordinator.receive(project("/tmp/x"))
        rig.clock.advance(3601)
        rig.coordinator.update(settings: rig.coordinator.settings)
        #expect(rig.log.intervals.first?.endReason == .timedOut)
    }

    @Test func interruptionAndDeadProcessAreTold() {
        let rig = makeRig()
        rig.coordinator.receive(AgentEvent(sessionID: "s", cwd: "/tmp/x", kind: .prompt, pid: 1, transcriptPath: "/t", transcriptSize: 0))
        rig.clock.advance(10)
        rig.probe.next = TranscriptScan(newOffset: 5, interrupted: true)
        rig.coordinator.checkLiveness()
        #expect(rig.log.intervals.last?.endReason == .interrupted)

        rig.coordinator.receive(AgentEvent(sessionID: "t", cwd: "/tmp/y", kind: .prompt, pid: 2, transcriptPath: nil, transcriptSize: nil))
        rig.clock.advance(10)
        rig.probe.alive = false
        rig.coordinator.checkLiveness()
        #expect(rig.log.intervals.last?.endReason == .processExited)
    }

    @Test func unexpectedStopsAreReportedButInterruptionsAreNot() {
        let rig = makeRig()
        var effects: [WakeEffect] = []
        rig.coordinator.onEffect = { effects.append($0) }

        // The user interrupts: quiet.
        rig.coordinator.receive(AgentEvent(sessionID: "s", cwd: "/tmp/x", kind: .prompt, pid: 1, transcriptPath: "/t", transcriptSize: 0))
        rig.clock.advance(60)
        rig.probe.next = TranscriptScan(newOffset: 5, interrupted: true)
        rig.coordinator.checkLiveness()
        #expect(effects.isEmpty)

        // The process vanishes: reported, with how long it had been working.
        rig.coordinator.receive(AgentEvent(sessionID: "t", cwd: "/tmp/y", kind: .prompt, pid: 2, transcriptPath: nil, transcriptSize: nil))
        rig.clock.advance(120)
        rig.probe.alive = false
        rig.coordinator.checkLiveness()
        #expect(effects == [.sessionStopped(cwd: "/tmp/y", duration: 120)])

        // Going silent past the safety timeout is reported once as well.
        effects.removeAll()
        rig.probe.alive = true
        rig.coordinator.receive(AgentEvent(sessionID: "u", cwd: "/tmp/z", kind: .prompt))
        rig.clock.advance(3601)
        rig.coordinator.update(settings: rig.coordinator.settings)
        rig.coordinator.update(settings: rig.coordinator.settings)
        #expect(effects == [.sessionStopped(cwd: "/tmp/z", duration: 3601)])
    }

    @Test func powerGuardEndsTheIntervalWithTheRightReason() {
        let rig = makeRig()
        rig.coordinator.receive(project("/tmp/x"))
        rig.clock.advance(10)
        rig.coordinator.update(power: PowerState(onBattery: true, batteryPercent: 10))
        #expect(rig.log.intervals.first?.endReason == .powerGuard)
    }

    @Test func quittingClosesTheRunningInterval() {
        let rig = makeRig()
        rig.coordinator.receive(project("/tmp/x"))
        rig.clock.advance(20)
        rig.coordinator.shutdown()
        #expect(rig.log.intervals.first?.endReason == .appQuit)
    }

    @Test func nothingIsRecordedWhileNothingIsHeld() {
        let rig = makeRig()
        rig.coordinator.receive(event(.finish, "ghost"))
        #expect(rig.log.open == nil)
        #expect(rig.log.intervals.isEmpty)
    }
}

@Suite struct ActivitySummaryTests {
    @Test func dailyTotalsSplitAnIntervalAtMidnight() {
        let late = HoldInterval(start: utc(2026, 10, 13, 23, 0), end: utc(2026, 10, 14, 1, 0),
                                sources: [.agent], projects: ["a"], endReason: .finished)
        let days = ActivitySummary.daily([late], now: utc(2026, 10, 14, 12), days: 3, calendar: utcCalendar())
        #expect(days.count == 3)
        #expect(days[1].agent == 3600) // 13th
        #expect(days[2].agent == 3600) // 14th
        #expect(days[0].total == 0)
    }

    @Test func agentTimeWinsOverManualWhenBothWereInvolved() {
        let both = HoldInterval(start: utc(2026, 10, 14, 9), end: utc(2026, 10, 14, 10),
                                sources: [.agent, .manual], projects: [], endReason: .released)
        let manualOnly = HoldInterval(start: utc(2026, 10, 14, 11), end: utc(2026, 10, 14, 11, 30),
                                      sources: [.manual], projects: [], endReason: .released)
        let today = ActivitySummary.daily([both, manualOnly], now: utc(2026, 10, 14, 12), days: 1, calendar: utcCalendar())[0]
        #expect(today.agent == 3600)
        #expect(today.manual == 1800)
    }

    @Test func daysWithoutActivityStillAppear() {
        let days = ActivitySummary.daily([], now: utc(2026, 10, 14, 12), days: 14, calendar: utcCalendar())
        #expect(days.count == 14)
        #expect(days.allSatisfy { $0.total == 0 })
    }

    @Test func projectTimeIsSplitEvenlyAndSorted() {
        let shared = HoldInterval(start: at(0), end: at(600), sources: [.agent], projects: ["a", "b"], endReason: .finished)
        let solo = HoldInterval(start: at(1000), end: at(1100), sources: [.agent], projects: ["a"], endReason: .finished)
        let totals = ActivitySummary.byProject([shared, solo], since: at(-1))
        #expect(totals.map(\.name) == ["a", "b"])
        #expect(totals[0].seconds == 400)
        #expect(totals[1].seconds == 300)
    }

    @Test func projectTimeIgnoresWhatHappenedBeforeTheWindow() {
        let old = HoldInterval(start: at(0), end: at(100), sources: [.agent], projects: ["a"], endReason: .finished)
        #expect(ActivitySummary.byProject([old], since: at(200)).isEmpty)
        #expect(ActivitySummary.byProject([old], since: at(50))[0].seconds == 50)
    }

    @Test func theRunningIntervalCountsUpToNow() {
        let open = openInterval(start: 0, lastSeen: 10, projects: ["a"])
        let all = ActivitySummary.all([], open: open, now: at(300))
        #expect(all.count == 1)
        #expect(all[0].duration == 300)
    }
}

@Suite struct FileActivityStoreTests {
    @Test func roundTripsIntervalsAndTheOpenState() {
        let (store, _) = makeFileStore()
        let saved = interval(0, 60, [.agent, .manual], ["a", "b"], .interrupted)
        store.append(saved)
        store.append(interval(100, 160))
        #expect(store.load().count == 2)
        #expect(store.load()[0].sources == saved.sources)
        #expect(store.load()[0].endReason == .interrupted)

        let open = OpenInterval(id: saved.id, start: at(0), sources: [.agent], projects: ["a"], lastSeen: at(5))
        store.saveOpen(open)
        #expect(store.loadOpen() == open)
        store.saveOpen(nil)
        #expect(store.loadOpen() == nil)
    }

    @Test func aDamagedLineCostsOnlyThatLine() throws {
        let (store, directory) = makeFileStore()
        store.append(interval(0, 60))
        try appendGarbageLine(to: directory)
        store.append(interval(100, 160))
        #expect(store.load().count == 2)
    }

    @Test func rewriteReplacesTheContent() {
        let (store, _) = makeFileStore()
        store.append(interval(0, 60))
        store.rewrite([])
        #expect(store.load().isEmpty)
    }
}
