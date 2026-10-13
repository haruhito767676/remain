import Testing
@testable import RemainCore

private func battery(_ percent: Int) -> PowerState {
    PowerState(onBattery: true, batteryPercent: percent)
}

private func working() -> WakeEngine {
    var engine = WakeEngine()
    engine.handle(event(.prompt), at: t0)
    return engine
}

@Suite struct PowerGuardTests {
    @Test func lowBatteryReleasesAndReportsOnce() {
        var engine = working()
        #expect(engine.setPower(battery(50)).isEmpty)
        #expect(engine.snapshot().prevention == .system)

        #expect(engine.setPower(battery(20)) == [.holdSuspended(.lowBattery(percent: 20))])
        #expect(engine.snapshot().prevention == .none)
        #expect(engine.snapshot().blockedBy == .lowBattery(percent: 20))

        // Already suspended: no second notification.
        #expect(engine.setPower(battery(19)).isEmpty)
    }

    @Test func acPowerIsNeverBlockedByBatteryLevel() {
        var engine = working()
        engine.setPower(PowerState(onBattery: false, batteryPercent: 3))
        #expect(engine.snapshot().prevention == .system)
        #expect(engine.snapshot().blockedBy == nil)
    }

    @Test func resumesOnlyFivePointsAboveTheCutoff() {
        var engine = working()
        engine.setPower(battery(20))
        engine.setPower(battery(24))
        #expect(engine.snapshot().prevention == .none) // still latched
        engine.setPower(battery(25))
        #expect(engine.snapshot().prevention == .system)
    }

    @Test func plugInResumesImmediately() {
        var engine = working()
        engine.setPower(battery(10))
        engine.setPower(PowerState(onBattery: false, batteryPercent: 10))
        #expect(engine.snapshot().prevention == .system)
    }

    @Test func cutoffOfZeroDisablesTheGuard() {
        var engine = working()
        engine.settings.batteryCutoffPercent = 0
        engine.setPower(battery(2))
        #expect(engine.snapshot().prevention == .system)
    }

    @Test func nothingWantedMeansNothingBlocked() {
        var engine = WakeEngine()
        #expect(engine.setPower(battery(5)).isEmpty)
        #expect(engine.snapshot().blockedBy == nil)
    }

    @Test func manualHoldIsGuardedToo() {
        var engine = WakeEngine()
        engine.setManual(.indefinite)
        engine.setPower(battery(15))
        #expect(engine.snapshot().prevention == .none)
    }

    @Test func raisingTheCutoffTripsTheGuardImmediately() {
        var engine = working()
        engine.setPower(battery(25))
        #expect(engine.snapshot().prevention == .system)
        engine.settings.batteryCutoffPercent = 30
        #expect(engine.snapshot().prevention == .none)
    }

    @Test func holdOnlyOnACBlocksBatteryPower() {
        var engine = working()
        engine.settings.holdOnlyOnAC = true
        #expect(engine.setPower(battery(90)) == [.holdSuspended(.onBatteryPower)])
    }

    @Test func lowPowerModeOnlyMattersWhenAskedFor() {
        var engine = working()
        engine.setPower(PowerState(lowPowerMode: true))
        #expect(engine.snapshot().prevention == .system)
        engine.settings.respectLowPowerMode = true
        #expect(engine.snapshot().blockedBy == .lowPowerMode)
    }

    @Test func onlyCriticalThermalStateReleases() {
        var engine = working()
        engine.setPower(PowerState(thermal: .serious))
        #expect(engine.snapshot().prevention == .system)
        #expect(engine.setPower(PowerState(thermal: .critical)) == [.holdSuspended(.overheating)])
        engine.settings.releaseWhenOverheating = false
        #expect(engine.snapshot().prevention == .system)
    }

    @Test func oldSavedSettingsGetPowerDefaults() throws {
        let settings = try decodeSettings(#"{"keepDisplayOn":true}"#)
        #expect(settings.batteryCutoffPercent == 20)
        #expect(!settings.holdOnlyOnAC)
        #expect(settings.releaseWhenOverheating)
    }
}

@MainActor
@Suite struct PowerGuardCoordinatorTests {
    @Test func lowBatteryDropsTheAssertionAndRaisesAnEffect() {
        let assertions = FakeAssertions()
        let coordinator = WakeCoordinator(assertions: assertions, probe: FakeProbe(), pollInterval: .seconds(3600))
        var effects: [WakeEffect] = []
        coordinator.onEffect = { effects.append($0) }

        coordinator.receive(event(.prompt))
        #expect(assertions.level == .system)

        coordinator.update(power: battery(12))
        #expect(assertions.level == .none)
        #expect(effects == [.holdSuspended(.lowBattery(percent: 12))])

        coordinator.update(power: PowerState(onBattery: false, batteryPercent: 12))
        #expect(assertions.level == .system)
    }

    @Test func readingTheRealPowerStateDoesNotCrash() {
        let state = SystemPowerMonitor.read()
        #expect(state.batteryPercent == nil || (0...100).contains(state.batteryPercent!))
    }
}

@MainActor
@Suite struct PowerMonitorDeliveryTests {
    /// Regression: with lid mode on at launch, `watchesLid` published before any handler was attached,
    /// the state was remembered as "published", and the handler then never received anything.
    @Test func aPublishBeforeTheHandlerExistsIsNotLost() {
        let source = PowerSource()
        let monitor = SystemPowerMonitor(reader: { source.state })
        monitor.watchesLid = true // publishes while nobody listens
        var received: [PowerState] = []
        monitor.onChange = { received.append($0) }
        #expect(received == [source.state]) // delivered as soon as a handler is attached
    }

    @Test func unchangedStatesAreNotRepeated() {
        let source = PowerSource()
        let monitor = SystemPowerMonitor(reader: { source.state })
        var received: [PowerState] = []
        monitor.onChange = { received.append($0) }
        monitor.publish()
        monitor.publish()
        #expect(received.count == 1)
        source.state.batteryPercent = 23
        monitor.publish()
        #expect(received.count == 2)
        #expect(received.last?.batteryPercent == 23)
    }

    @Test func replacingTheHandlerDeliversTheCurrentStateAgain() {
        let source = PowerSource()
        let monitor = SystemPowerMonitor(reader: { source.state })
        monitor.onChange = { _ in }
        var second: [PowerState] = []
        monitor.onChange = { second.append($0) }
        #expect(second.count == 1)
    }

    @Test func removingTheHandlerStopsDelivery() {
        let source = PowerSource()
        let monitor = SystemPowerMonitor(reader: { source.state })
        var received = 0
        monitor.onChange = { _ in received += 1 }
        monitor.onChange = nil
        source.state.batteryPercent = 5
        monitor.publish()
        #expect(received == 1)
    }
}
