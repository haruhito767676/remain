import Testing
@testable import RemainCore

@Suite struct HookDecoderTests {
    @Test func claudeAndCodexShareThePayloadShape() {
        let json = #"{"session_id":"s1","hook_event_name":"UserPromptSubmit","cwd":"/work/app","transcript_path":"/t.jsonl"}"#
        let claude = decodeEvent(.claudeCode, nil, json)
        #expect(claude?.kind == .prompt)
        #expect(claude?.agent == .claudeCode)
        #expect(claude?.transcriptPath == "/t.jsonl") // Claude's log is scanned for interruptions

        let codex = decodeEvent(.codex, nil, json)
        #expect(codex?.agent == .codex)
        #expect(codex?.transcriptPath == nil) // we do not know Codex's log format: not scanned
    }

    @Test func codexInterruptAndPermissionEvents() {
        func kind(_ name: String) -> AgentEvent.Kind? {
            decodeEvent(.codex, nil, #"{"session_id":"s","hook_event_name":"\#(name)"}"#)?.kind
        }
        #expect(kind("Interrupt") == .interrupted)
        #expect(kind("PermissionRequest") == .attention)
        #expect(kind("Stop") == .finish)
        #expect(kind("PreToolUse") == .activity)
        #expect(kind("Unheard") == nil)
    }

    @Test func antigravityEventsComeFromTheArgument() {
        let body = #"{"conversationId":"c1","workspacePaths":["/work/app","/other"],"transcriptPath":"/x/transcript.jsonl"}"#
        let start = decodeEvent(.antigravity, "PreInvocation", body)
        #expect(start?.kind == .start)
        #expect(start?.sessionID == "c1")
        #expect(start?.cwd == "/work/app")
        #expect(start?.agent == .antigravity)
        #expect(start?.transcriptPath == nil)
        #expect(decodeEvent(.antigravity, "SessionStart", body)?.kind == .start)
        #expect(decodeEvent(.antigravity, "PostInvocation", body)?.kind == .activity)
        #expect(decodeEvent(.antigravity, "PostToolUse", body)?.kind == .activity)
        #expect(decodeEvent(.antigravity, "Whatever", body) == nil)
        #expect(decodeEvent(.antigravity, nil, body) == nil) // without the argument we cannot tell
    }

    @Test func antigravityStopOnlyFinishesWhenFullyIdle() {
        func kind(_ idle: String) -> AgentEvent.Kind? {
            decodeEvent(.antigravity, "Stop", #"{"conversationId":"c","fullyIdle":\#(idle),"terminationReason":"model_stop"}"#)?.kind
        }
        #expect(kind("true") == .finish)
        #expect(kind("false") == .activity) // background commands still running
        #expect(decodeEvent(.antigravity, "Stop", #"{"conversationId":"c"}"#)?.kind == .finish)
    }

    @Test func garbageIsIgnored() {
        #expect(decodeEvent(.claudeCode, nil, "not json") == nil)
        #expect(decodeEvent(.antigravity, "Stop", "{}") == nil)
    }

    @Test func claudeCodeMustStaySilentAntigravityMustAnswer() {
        #expect(HookDecoder.response(agent: .claudeCode, eventName: "UserPromptSubmit") == nil)
        #expect(HookDecoder.response(agent: .codex, eventName: "Stop") == nil)
        #expect(HookDecoder.response(agent: .antigravity, eventName: "PostToolUse") == "{}")
        #expect(HookDecoder.response(agent: .antigravity, eventName: "Stop") == #"{"decision":"allow"}"#)
    }

    @Test func eventsSurviveTheIPCRoundTrip() throws {
        let event = AgentEvent(sessionID: "s", cwd: "/a", kind: .start, pid: 7, transcriptPath: "/t", transcriptSize: 9, agent: .antigravity)
        #expect(try roundTrip(event) == event)
    }
}

@Suite struct AgentKindTests {
    @Test func cliNamesRoundTrip() {
        for kind in AgentKind.allCases { #expect(AgentKind(cliName: kind.cliName) == kind) }
        #expect(AgentKind(cliName: "nope") == nil)
    }

    @Test func processMatching() {
        #expect(AgentKind.claudeCode.ownsProcess(named: "claude"))
        #expect(AgentKind.claudeCode.ownsProcess(named: "claude.exe"))
        #expect(!AgentKind.claudeCode.ownsProcess(named: "zsh"))
        #expect(AgentKind.codex.ownsProcess(named: "codex"))
        #expect(AgentKind.antigravity.ownsProcess(named: "Antigravity Helper"))
        #expect(AgentKind.antigravity.ownsProcess(named: "language_server_macos_arm"))
        #expect(!AgentKind.antigravity.ownsProcess(named: "claude"))
        #expect(!AgentKind.command.ownsProcess(named: "claude"))
    }
}

@Suite struct StartAndInterruptEngineTests {
    private func start(_ id: String = "a", agent: AgentKind = .antigravity) -> AgentEvent {
        AgentEvent(sessionID: id, kind: .start, agent: agent)
    }

    @Test func startCreatesASession() {
        var engine = WakeEngine()
        engine.handle(start(), at: t0)
        #expect(engine.snapshot().workingCount == 1)
        #expect(engine.sessions["a"]?.agent == .antigravity)
    }

    @Test func startKeepsTheOriginalStartTime() {
        var engine = WakeEngine()
        engine.handle(start(), at: t0)
        engine.handle(start(), at: at(500)) // every model call sends one
        #expect(engine.sessions["a"]?.startedAt == t0)
        #expect(engine.sessions["a"]?.lastSeen == at(500))
        let finish = engine.handle(event(.finish), at: at(600))
        #expect(finish.contains(.sessionFinished(cwd: nil, duration: 600)))
    }

    @Test func startResumesAWaitingSession() {
        var engine = WakeEngine()
        engine.handle(start(), at: t0)
        engine.handle(event(.attention), at: at(5))
        engine.handle(start(), at: at(9))
        #expect(engine.snapshot().workingCount == 1)
    }

    @Test func interruptedEndsQuietly() {
        var engine = WakeEngine()
        engine.handle(start(), at: t0)
        let effects = engine.handle(AgentEvent(sessionID: "a", kind: .interrupted, agent: .antigravity), at: at(5))
        #expect(effects.isEmpty) // no notification, no completion action: the user is right there
        #expect(engine.snapshot().prevention == .none)
    }

    @Test func aLateStopAfterStartIsStillOneFinish() {
        var engine = WakeEngine()
        engine.handle(start(), at: t0)
        #expect(!engine.handle(event(.finish), at: at(5)).isEmpty)
        #expect(engine.handle(event(.finish), at: at(6)).isEmpty)
    }
}

@MainActor
@Suite struct InterruptCoordinatorTests {
    @Test func aDirectInterruptIsRecordedAsInterrupted() {
        let clock = TestClock()
        let log = ActivityLog(store: MemoryActivityStore(), now: { t0 })
        let coordinator = WakeCoordinator(assertions: FakeAssertions(), probe: FakeProbe(), activity: log,
                                          pollInterval: .seconds(3600), now: { clock.current })
        coordinator.receive(AgentEvent(sessionID: "s", cwd: "/a/proj", kind: .prompt, agent: .codex))
        clock.advance(20)
        coordinator.receive(AgentEvent(sessionID: "s", kind: .interrupted, agent: .codex))
        #expect(log.intervals.first?.endReason == .interrupted)
        #expect(log.intervals.first?.agents == [.codex])
    }

    @Test func intervalsRememberWhichToolsWorked() {
        let clock = TestClock()
        let log = ActivityLog(store: MemoryActivityStore(), now: { t0 })
        let coordinator = WakeCoordinator(assertions: FakeAssertions(), probe: FakeProbe(), activity: log,
                                          pollInterval: .seconds(3600), now: { clock.current })
        coordinator.receive(AgentEvent(sessionID: "a", kind: .prompt, agent: .claudeCode))
        coordinator.receive(AgentEvent(sessionID: "b", kind: .start, agent: .antigravity))
        clock.advance(30)
        coordinator.receive(AgentEvent(sessionID: "a", kind: .finish, agent: .claudeCode))
        coordinator.receive(AgentEvent(sessionID: "b", kind: .finish, agent: .antigravity))
        #expect(log.intervals.first?.agents == [.claudeCode, .antigravity])
    }

    @Test func recordsWrittenBeforeAgentsExistStillLoad() throws {
        let old = #"{"id":"8D3A2B1C-0000-4000-8000-000000000001","start":"2026-10-13T01:00:00Z","end":"2026-10-13T01:10:00Z","sources":["agent"],"projects":["remain"],"endReason":"finished"}"#
        let interval = try decodeInterval(old)
        #expect(interval.agents.isEmpty)
        #expect(interval.projects == ["remain"])
    }
}

@Suite struct AntigravityInstallerTests {
    @Test func installsOwnEntryWithTheRightCommands() throws {
        let installer = try makeAntigravityInstaller()
        #expect(!installer.isInstalled())
        try installer.install()
        #expect(installer.isInstalled())
        let ours = try #require(readJSON(installer.configURL)["remain"] as? [String: Any])
        for event in ["SessionStart", "PreInvocation", "PostInvocation", "Stop"] {
            let handlers = try #require(ours[event] as? [[String: Any]])
            #expect(handlers[0]["command"] as? String == "/Applications/remAIn.app/Contents/Helpers/remain hook antigravity \(event)")
        }
        // PostToolUse uses the matcher form.
        let tool = try #require(ours["PostToolUse"] as? [[String: Any]])
        #expect(tool[0]["matcher"] as? String == "")
        #expect(ours["PreToolUse"] == nil) // PreToolUse needs a decision from us: stay out of it
    }

    @Test func otherHooksAreLeftAlone() throws {
        let installer = try makeAntigravityInstaller(existing: #"{"my-linter":{"PostToolUse":[{"matcher":"x","hooks":[{"type":"command","command":"lint"}]}]},"other":{"enabled":false}}"#)
        try installer.install()
        let root = try readJSON(installer.configURL)
        #expect(root["my-linter"] != nil)
        #expect(root["other"] != nil)
        try installer.uninstall()
        let after = try readJSON(installer.configURL)
        #expect(after["remain"] == nil)
        #expect(after["my-linter"] != nil)
    }

    @Test func installIsIdempotent() throws {
        let installer = try makeAntigravityInstaller()
        try installer.install()
        try installer.install()
        #expect(installer.isInstalled())
        #expect((try readJSON(installer.configURL)).count == 1)
    }

    @Test func movedExecutableNeedsRepair() throws {
        let old = try makeAntigravityInstaller(executable: "/old/place/remain")
        try old.install()
        let current = AntigravityHookInstaller(configURL: old.configURL, executablePath: "/new/place/remain")
        #expect(current.isInstalled()) // the hooks are there ...
        #expect(current.needsRepair()) // ... but point at the old location
        try current.install()
        #expect(!current.needsRepair())
    }

    @Test func notInstalledDoesNotNeedRepair() throws {
        #expect(try !makeAntigravityInstaller().needsRepair())
    }

    @Test func brokenJSONIsNeverOverwritten() throws {
        let installer = try makeAntigravityInstaller(existing: "{ nope")
        #expect(throws: (any Error).self) { try installer.install() }
        #expect(try String(contentsOf: installer.configURL, encoding: .utf8) == "{ nope")
    }
}

@Suite struct ClaudeRepairTests {
    @Test func movedAppNeedsRepairAndRepairWorks() throws {
        let old = try installerAt("/old/remain")
        try old.install()
        let moved = HookInstaller(settingsURL: old.settingsURL, executablePath: "/new/remain")
        #expect(moved.isInstalled()) // the hooks are there ...
        #expect(moved.needsRepair()) // ... but point at the old location
        try moved.install()
        #expect(!moved.needsRepair())
        let hooks = try readJSON(old.settingsURL)["hooks"] as! [String: Any]
        #expect((hooks["Stop"] as! [Any]).count == 1) // replaced, not duplicated
    }
}
