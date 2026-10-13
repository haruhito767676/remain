import Testing
@testable import RemainCore

private func lidSettings() -> WakeSettings {
    var settings = WakeSettings()
    settings.keepRunningWithLidClosed = true
    return settings
}

@Suite struct LidEngineTests {
    @Test func offByDefault() {
        var engine = WakeEngine()
        engine.handle(event(.prompt), at: t0)
        #expect(engine.snapshot().preventLidSleep == false)
    }

    @Test func wantedOnlyWhileSomethingHolds() {
        var engine = WakeEngine(settings: lidSettings())
        #expect(engine.snapshot().preventLidSleep == false)
        engine.handle(event(.prompt), at: t0)
        #expect(engine.snapshot().preventLidSleep)
        engine.handle(event(.finish), at: at(5))
        #expect(engine.snapshot().preventLidSleep == false)
    }

    @Test func blockedByPowerConditions() {
        var engine = WakeEngine(settings: lidSettings())
        engine.handle(event(.prompt), at: t0)
        engine.setPower(PowerState(onBattery: true, batteryPercent: 10))
        #expect(engine.snapshot().preventLidSleep == false)
    }

    @Test func timeLimitEndsLidPreventionButNotTheHold() {
        var settings = lidSettings()
        settings.lidClosedLimit = 3600
        var engine = WakeEngine(settings: settings)
        engine.handle(event(.prompt), at: t0)
        #expect(engine.updateLid(at: t0).isEmpty)
        #expect(engine.updateLid(at: at(3599)).isEmpty)
        #expect(engine.updateLid(at: at(3600)) == [.lidLimitReached])
        #expect(engine.snapshot().preventLidSleep == false)
        #expect(engine.snapshot().prevention == .system) // the normal hold carries on
        #expect(engine.updateLid(at: at(4000)).isEmpty)   // reported once
    }

    @Test func limitStartsOverWithTheNextHold() {
        var settings = lidSettings()
        settings.lidClosedLimit = 100
        var engine = WakeEngine(settings: settings)
        engine.handle(event(.prompt), at: t0)
        engine.updateLid(at: at(101))
        engine.handle(event(.finish), at: at(102))
        engine.updateLid(at: at(103)) // nothing held: resets
        engine.handle(event(.prompt), at: at(200))
        engine.updateLid(at: at(200))
        #expect(engine.snapshot().preventLidSleep)
    }

    @Test func thermalIsStricterOnlyWhenTheLidIsClosed() {
        var engine = WakeEngine(settings: lidSettings())
        engine.handle(event(.prompt), at: t0)
        engine.setPower(PowerState(thermal: .serious, lidClosed: false))
        #expect(engine.snapshot().prevention == .system) // open lid: serious is tolerated
        engine.setPower(PowerState(thermal: .serious, lidClosed: true))
        #expect(engine.snapshot().blockedBy == .overheating)
        #expect(engine.snapshot().preventLidSleep == false)
    }

    @Test func closedLidProtectionDoesNotDependOnTheOverheatingToggle() {
        var settings = lidSettings()
        settings.releaseWhenOverheating = false
        var engine = WakeEngine(settings: settings)
        engine.handle(event(.prompt), at: t0)
        engine.setPower(PowerState(thermal: .serious, lidClosed: true))
        #expect(engine.snapshot().blockedBy == .overheating)
    }

    @Test func withoutTheLidFeatureSeriousHeatIsTolerated() {
        var engine = WakeEngine()
        engine.handle(event(.prompt), at: t0)
        engine.setPower(PowerState(thermal: .serious, lidClosed: true))
        #expect(engine.snapshot().prevention == .system)
    }

    @Test func deadlineIncludesTheLidLimit() {
        var settings = lidSettings()
        settings.lidClosedLimit = 600
        var engine = WakeEngine(settings: settings)
        engine.handle(event(.prompt), at: t0)
        engine.updateLid(at: t0)
        #expect(engine.nextDeadline() == at(600))
    }

    @Test func oldSettingsDecodeWithLidDefaults() throws {
        let settings = try decodeSettings(#"{"keepDisplayOn":true}"#)
        #expect(settings.keepRunningWithLidClosed == false)
        #expect(settings.lidClosedLimit == 3 * 3600)
    }
}

@MainActor
@Suite struct LidControllerTests {
    private func make() -> (LidSleepController, FakeDisabler, FakeHeartbeat) {
        let disabler = FakeDisabler(), heartbeat = FakeHeartbeat()
        return (LidSleepController(disabler: disabler, heartbeat: heartbeat, heartbeatInterval: .seconds(3600)), disabler, heartbeat)
    }

    @Test func engagingWritesHeartbeatAndDisablesSleep() {
        let (controller, disabler, heartbeat) = make()
        controller.apply(prevent: true, lidClosed: false)
        #expect(controller.engaged)
        #expect(disabler.disabled)
        #expect(heartbeat.present)
    }

    @Test func notSetUpRefusesToEngage() {
        let (controller, disabler, heartbeat) = make()
        disabler.ready = false
        var failure: LidFailure?
        controller.onFailure = { failure = $0 }
        controller.apply(prevent: true, lidClosed: false)
        #expect(!controller.engaged)
        #expect(failure == .notSetUp)
        #expect(!heartbeat.present)
        #expect(disabler.setCalls.isEmpty)
    }

    @Test func aFailingCommandLeavesNothingBehind() {
        let (controller, disabler, heartbeat) = make()
        disabler.succeeds = false
        var failure: LidFailure?
        controller.onFailure = { failure = $0 }
        controller.apply(prevent: true, lidClosed: false)
        #expect(!controller.engaged)
        #expect(failure == .commandFailed)
        #expect(!heartbeat.present)
    }

    @Test func applyingTwiceDoesNothingTheSecondTime() {
        let (controller, disabler, _) = make()
        controller.apply(prevent: true, lidClosed: false)
        controller.apply(prevent: true, lidClosed: false)
        #expect(disabler.setCalls == [true])
    }

    @Test func releasingWithTheLidClosedPutsTheMacToSleep() {
        let (controller, disabler, heartbeat) = make()
        controller.apply(prevent: true, lidClosed: true)
        controller.apply(prevent: false, lidClosed: true)
        #expect(!controller.engaged)
        #expect(!disabler.disabled)
        #expect(!heartbeat.present)
        #expect(disabler.sleepNowCalls == 1)
    }

    @Test func releasingWithTheLidOpenDoesNotForceSleep() {
        let (controller, disabler, _) = make()
        controller.apply(prevent: true, lidClosed: false)
        controller.apply(prevent: false, lidClosed: false)
        #expect(disabler.sleepNowCalls == 0)
    }

    @Test func afterAFailureItDoesNotRetryAtOnce() {
        let disabler = FakeDisabler()
        disabler.ready = false
        let clock = TestClock()
        let controller = LidSleepController(disabler: disabler, heartbeat: FakeHeartbeat(), heartbeatInterval: .seconds(3600),
                                            retryInterval: 30, now: { clock.current })
        var failures = 0
        controller.onFailure = { _ in failures += 1 }

        controller.apply(prevent: true, lidClosed: false)
        controller.apply(prevent: true, lidClosed: false)
        #expect(failures == 1) // the second call came straight after: no new attempt, no new complaint

        clock.advance(31)
        controller.apply(prevent: true, lidClosed: false)
        #expect(failures == 2)

        disabler.ready = true
        clock.advance(31)
        controller.apply(prevent: true, lidClosed: false)
        #expect(controller.engaged)
    }

    @Test func releaseWithoutEngagingDoesNothing() {
        let (controller, disabler, _) = make()
        controller.apply(prevent: false, lidClosed: true)
        #expect(disabler.setCalls.isEmpty)
        #expect(disabler.sleepNowCalls == 0)
    }

    @Test func quittingReleasesSleepAndTheHeartbeat() {
        let (controller, disabler, heartbeat) = make()
        controller.apply(prevent: true, lidClosed: false)
        controller.shutdown()
        #expect(!disabler.disabled)
        #expect(!heartbeat.present)
    }

    @Test func leftoverFromACrashIsRepairedOnLaunch() {
        let (controller, disabler, heartbeat) = make()
        heartbeat.plant()
        disabler.forceDisabled(true)
        controller.recoverOnLaunch()
        #expect(!disabler.disabled)
        #expect(!heartbeat.present)
    }

    @Test func aSettingTheUserMadeByHandIsLeftAlone() {
        let (controller, disabler, heartbeat) = make()
        disabler.forceDisabled(true) // no heartbeat: not ours
        controller.recoverOnLaunch()
        #expect(disabler.disabled)
        #expect(!heartbeat.present)
    }
}

@MainActor
@Suite struct LidCoordinatorTests {
    private func make(lidEnabled: Bool = true) -> (WakeCoordinator, FakeLid, TestClock) {
        var settings = WakeSettings()
        settings.keepRunningWithLidClosed = lidEnabled
        let clock = TestClock()
        let lid = FakeLid()
        let coordinator = WakeCoordinator(settings: settings, assertions: FakeAssertions(), probe: FakeProbe(),
                                          pollInterval: .seconds(3600), now: { clock.current })
        coordinator.lid = lid
        return (coordinator, lid, clock)
    }

    @Test func engagesWhileAnAgentWorksAndReleasesWhenItFinishes() {
        let (coordinator, lid, _) = make()
        coordinator.receive(event(.prompt))
        #expect(lid.calls.last?.prevent == true)
        coordinator.receive(event(.finish))
        #expect(lid.calls.last?.prevent == false)
    }

    @Test func reportsTheLidStateWhenReleasing() {
        let (coordinator, lid, _) = make()
        coordinator.receive(event(.prompt))
        coordinator.update(power: PowerState(lidClosed: true))
        coordinator.receive(event(.finish))
        #expect(lid.calls.last?.lidClosed == true)
    }

    @Test func neverEngagesWhenTheFeatureIsOff() {
        let (coordinator, lid, _) = make(lidEnabled: false)
        coordinator.receive(event(.prompt))
        #expect(lid.calls.allSatisfy { !$0.prevent })
    }

    @Test func theTimeLimitReleasesLidPreventionAndRaisesAnEffect() {
        let (coordinator, lid, clock) = make()
        var effects: [WakeEffect] = []
        coordinator.onEffect = { effects.append($0) }
        coordinator.receive(event(.prompt))
        // A busy agent keeps reporting (otherwise the silence timeout would end the hold first).
        for _ in 0..<5 {
            clock.advance(1800)
            coordinator.receive(event(.activity))
        }
        #expect(!effects.contains(.lidLimitReached)) // 2.5 hours in
        clock.advance(1800)
        coordinator.receive(event(.activity)) // 3 hours: the limit is reached
        #expect(effects.contains(.lidLimitReached))
        #expect(lid.calls.last?.prevent == false)
        #expect(coordinator.snapshot.prevention == .system) // the agent is still held awake normally
    }

    @Test func quittingShutsTheLidControllerDown() {
        let (coordinator, lid, _) = make()
        coordinator.shutdown()
        #expect(lid.shutdowns == 1)
    }
}

@Suite struct LidSupportTests {
    @Test func sudoersAllowsExactlyTheTwoCommands() throws {
        let content = try #require(sudoersContent(for: "alice"))
        let rules = content.split(separator: "\n").filter { !$0.hasPrefix("#") }
        #expect(rules.count == 1)
        #expect(rules[0] == "alice ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, /usr/bin/pmset disablesleep 1")
    }

    @Test func unsafeAccountNamesAreRefused() {
        for name in ["", "al ice", "a;b", "alice\nroot ALL=(ALL) NOPASSWD: ALL", "a'b", "al\"ice", "ünï"] {
            #expect(sudoersContent(for: name) == nil)
        }
        #expect(sudoersContent(for: "first.last-2_x") != nil)
    }

    @Test func watchdogScriptIsValidShell() throws {
        #expect(try WatchdogRun.syntaxCheck() == 0)
    }

    @Test func watchdogLeavesAFreshHeartbeatAlone() throws {
        let run = try WatchdogRun()
        try run.plantHeartbeat(ageSeconds: 5)
        try run.run()
        #expect(run.heartbeatExists)
    }

    @Test func watchdogIgnoresAMissingHeartbeat() throws {
        let run = try WatchdogRun()
        #expect(try run.run() == 0)
        #expect(!run.heartbeatExists)
    }

    @Test func watchdogActsOnAStaleHeartbeat() throws {
        let run = try WatchdogRun()
        try run.plantHeartbeat(ageSeconds: 120)
        try run.run()
        #expect(!run.heartbeatExists) // it cleaned up after re-enabling sleep
    }

    @Test func launchAgentPlistIsWellFormed() throws {
        let plist = try watchdogPlistObject()
        #expect(plist["Label"] as? String == LidSupport.agentLabel)
        #expect(plist["StartInterval"] as? Int == 15)
        let arguments = try #require(plist["ProgramArguments"] as? [String])
        #expect(arguments.first == "/bin/sh")
        #expect(arguments.last?.hasSuffix("lid-watchdog.sh") == true)
        #expect(arguments.last?.contains("Application Support") == true)
    }

    @Test func adminScriptEscapesQuotesAndBackslashes() {
        let script = adminScript(#"echo "a\b" && echo 'c'"#)
        #expect(script == #"do shell script "echo \"a\\b\" && echo 'c'" with administrator privileges"#)
    }
}
