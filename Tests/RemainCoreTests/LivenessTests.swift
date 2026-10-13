import Testing
@testable import RemainCore

private let userInterrupt = #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}"#
private let toolUseInterrupt = #"{"type":"user","message":{"role":"user","content":"[Request interrupted by user for tool use]"}}"#

@Suite struct TranscriptScannerTests {
    @Test func detectsInterruptionRecordedAsTextBlock() {
        #expect(scan([userInterrupt]))
    }

    @Test func detectsInterruptionRecordedAsPlainString() {
        #expect(scan([toolUseInterrupt]))
    }

    @Test func ignoresMarkerInsideAssistantOutput() {
        let assistant = #"{"type":"assistant","message":{"content":[{"type":"text","text":"[Request interrupted by user]"}]}}"#
        #expect(!scan([assistant]))
    }

    @Test func ignoresMarkerInsideToolResult() {
        let result = #"{"type":"user","message":{"content":[{"type":"tool_result","content":"[Request interrupted by user]"}]}}"#
        #expect(!scan([result]))
    }

    @Test func ignoresOrdinaryUserMessageMentioningTheMarker() {
        let user = #"{"type":"user","message":{"content":"what does [Request interrupted by user] mean?"}}"#
        #expect(!scan([user]))
    }

    @Test func scanOnlyLooksAfterTheOffset() throws {
        let old = userInterrupt + "\n"
        let result = try scanFile(old + #"{"type":"user","message":{"content":"next"}}"# + "\n", from: UInt64(old.utf8.count))
        #expect(!result.interrupted)
    }

    @Test func scanFindsNewInterruptionAndAdvances() throws {
        let prefix = #"{"type":"user","message":{"content":"go"}}"# + "\n"
        let text = prefix + userInterrupt + "\n"
        let result = try scanFile(text, from: UInt64(prefix.utf8.count))
        #expect(result.interrupted)
        #expect(result.newOffset == UInt64(text.utf8.count))
    }

    @Test func halfWrittenLineIsLeftForNextTime() throws {
        let partial = String(userInterrupt.prefix(40)) // no trailing newline
        let result = try scanFile(partial)
        #expect(!result.interrupted)
        #expect(result.newOffset == 0)
    }
}

@MainActor
@Suite struct LivenessCoordinatorTests {
    private func make() -> (WakeCoordinator, FakeAssertions, FakeProbe) {
        let assertions = FakeAssertions()
        let probe = FakeProbe()
        let coordinator = WakeCoordinator(assertions: assertions, probe: probe, pollInterval: .seconds(3600))
        return (coordinator, assertions, probe)
    }

    private func startSession(_ coordinator: WakeCoordinator, pid: Int32? = 4242, path: String? = "/tmp/x.jsonl") {
        coordinator.receive(AgentEvent(sessionID: "s", kind: .prompt, pid: pid, transcriptPath: path, transcriptSize: 0))
    }

    @Test func deadProcessReleasesTheMac() {
        let (coordinator, assertions, probe) = make()
        startSession(coordinator)
        #expect(assertions.level == .system)
        probe.alive = false
        coordinator.checkLiveness()
        #expect(assertions.level == .none)
        #expect(coordinator.snapshot.workingCount == 0)
    }

    @Test func interruptionReleasesTheMacSilently() {
        let (coordinator, assertions, probe) = make()
        var effects: [WakeEffect] = []
        coordinator.onEffect = { effects.append($0) }
        startSession(coordinator)
        probe.next = TranscriptScan(newOffset: 10, interrupted: true)
        coordinator.checkLiveness()
        #expect(assertions.level == .none)
        #expect(effects.isEmpty)
    }

    @Test func healthySessionKeepsHolding() {
        let (coordinator, assertions, probe) = make()
        startSession(coordinator)
        probe.next = TranscriptScan(newOffset: 99, interrupted: false)
        coordinator.checkLiveness()
        #expect(assertions.level == .system)
    }

    @Test func sessionWithoutProcessInfoIsUntouched() {
        let (coordinator, assertions, probe) = make()
        startSession(coordinator, pid: nil, path: nil)
        probe.alive = false
        coordinator.checkLiveness()
        #expect(assertions.level == .system)
    }
}

@Suite struct ProcessTreeTests {
    @Test func parentLookupMatchesTheKernel() {
        #expect(ProcessTree.parent(of: ownPID()) == parentPID())
    }

    @Test func executableNameIsResolved() {
        #expect(ProcessTree.executableName(of: ownPID()) != nil)
    }

    @Test func onlyClaudeBinariesAreRecognised() {
        #expect(ProcessTree.claudeNames.contains("claude"))
        #expect(ProcessTree.claudeNames.contains("claude.exe"))
        #expect(!ProcessTree.claudeNames.contains("zsh"))
    }
}
