import Testing
@testable import RemainCore

@Suite struct WakeEngineTests {
    @Test func idleByDefault() {
        #expect(WakeEngine().snapshot().prevention == .none)
    }

    @Test func promptStartsHolding_stopReleases() {
        var engine = WakeEngine()
        engine.handle(event(.prompt), at: t0)
        #expect(engine.snapshot().prevention == .system)
        #expect(engine.snapshot().workingCount == 1)
        engine.handle(event(.finish), at: at(10))
        #expect(engine.snapshot().prevention == .none)
    }

    @Test func displayOnlyWhenRequested() {
        var settings = WakeSettings()
        settings.keepDisplayOn = true
        var engine = WakeEngine(settings: settings)
        engine.handle(event(.prompt), at: t0)
        #expect(engine.snapshot().prevention == .systemAndDisplay)
    }

    @Test func waitingReleasesUnlessConfigured() {
        var engine = WakeEngine()
        engine.handle(event(.prompt), at: t0)
        engine.handle(event(.attention), at: at(5))
        #expect(engine.snapshot().prevention == .none)
        #expect(engine.snapshot().waitingCount == 1)

        engine.settings.holdWhileWaiting = true
        #expect(engine.snapshot().prevention == .system)
    }

    @Test func toolActivityResumesAfterApproval() {
        var engine = WakeEngine()
        engine.handle(event(.prompt), at: t0)
        engine.handle(event(.attention), at: at(5))
        engine.handle(event(.activity), at: at(20))
        #expect(engine.snapshot().workingCount == 1)
        #expect(engine.snapshot().prevention == .system)
    }

    @Test func lateActivityDoesNotResurrectFinishedSession() {
        var engine = WakeEngine()
        engine.handle(event(.prompt), at: t0)
        engine.handle(event(.finish), at: at(1))
        engine.handle(event(.activity), at: at(2))
        #expect(engine.snapshot().prevention == .none)
    }

    @Test func silentSessionExpires() {
        var engine = WakeEngine()
        engine.handle(event(.prompt), at: t0)
        engine.expire(at: at(engine.settings.sessionTimeout - 1))
        #expect(engine.snapshot().prevention == .system)
        engine.expire(at: at(engine.settings.sessionTimeout + 1))
        #expect(engine.snapshot().prevention == .none)
    }

    @Test func activityRefreshesTimeout() {
        var engine = WakeEngine()
        engine.handle(event(.prompt), at: t0)
        engine.handle(event(.activity), at: at(600))
        engine.expire(at: at(600 + engine.settings.sessionTimeout - 1))
        #expect(engine.snapshot().prevention == .system)
    }

    @Test func sessionsAreIndependent() {
        var engine = WakeEngine()
        engine.handle(event(.prompt, "a"), at: t0)
        engine.handle(event(.prompt, "b"), at: t0)
        engine.handle(event(.finish, "a"), at: at(1))
        #expect(engine.snapshot().prevention == .system)
        engine.handle(event(.finish, "b"), at: at(2))
        #expect(engine.snapshot().prevention == .none)
    }

    @Test func manualTimerExpires() {
        var engine = WakeEngine()
        engine.setManual(.until(at(60)))
        #expect(engine.snapshot().prevention == .system)
        engine.expire(at: at(61))
        #expect(engine.snapshot().prevention == .none)
    }

    @Test func nextDeadlineIsEarliest() {
        var engine = WakeEngine()
        #expect(engine.nextDeadline() == nil)
        engine.handle(event(.prompt), at: t0)
        engine.setManual(.until(at(60)))
        #expect(engine.nextDeadline() == at(60))
    }
}

@Suite struct HookPayloadTests {
    @Test func decodesClaudeCodeJSON() throws {
        let payload = try decodeHook(
            #"{"session_id":"abc","hook_event_name":"UserPromptSubmit","cwd":"/tmp","prompt":"hi"}"#
        )
        #expect(payload.agentEvent == AgentEvent(sessionID: "abc", cwd: "/tmp", kind: .prompt))
    }

    @Test func mapsEvents() {
        func kind(_ name: String) -> AgentEvent.Kind? {
            HookPayload(sessionID: "s", eventName: name).agentEvent?.kind
        }
        #expect(kind("PreToolUse") == .activity)
        #expect(kind("PostToolUse") == .activity)
        #expect(kind("Notification") == .attention)
        #expect(kind("Stop") == .finish)
        #expect(kind("SessionEnd") == .finish)
        #expect(kind("SomethingNew") == nil)
    }
}
