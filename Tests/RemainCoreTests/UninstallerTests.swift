import Testing
@testable import RemainCore

@Suite struct UninstallerTests {
    private func uninstaller(_ fake: FakeHome, support: SupportDirectory) -> Uninstaller {
        Uninstaller(manager: fake.manager(), lid: nil, supportDirectory: support.url)
    }

    @Test func removesOurHooksFromEveryTool() throws {
        let fake = try FakeHome()
        try fake.makeDirectory(".claude")
        let manager = fake.manager()
        for agent in AgentKind.integrable { try manager.install(agent) }

        let report = uninstaller(fake, support: try SupportDirectory(files: [])).removeEverything()

        #expect(Set(report.hooksRemoved) == Set(AgentKind.integrable))
        for agent in AgentKind.integrable { #expect(manager.state(of: agent) != .installed) }
        #expect(report.errors.isEmpty)
    }

    @Test func theUsersOwnHooksSurvive() throws {
        let fake = try FakeHome()
        try fake.makeDirectory(".claude")
        try fake.write(".claude/settings.json",
                       #"{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#)
        try fake.manager().install(.claudeCode)

        _ = uninstaller(fake, support: try SupportDirectory(files: [])).removeEverything()

        let root = try fake.json(".claude/settings.json")
        #expect(root["model"] as? String == "opus")
        let stop = (root["hooks"] as! [String: Any])["Stop"] as! [Any]
        #expect(stop.count == 1) // only "say done" is left
    }

    @Test func toolsThatWereNeverConnectedAreNotTouched() throws {
        let fake = try FakeHome()
        let report = uninstaller(fake, support: try SupportDirectory(files: [])).removeEverything()
        #expect(report.hooksRemoved.isEmpty)
        #expect(!fake.has(".gemini/config/hooks.json"))
        #expect(!fake.has(".codex/hooks.json"))
    }

    @Test func historyAndHelperFilesAreRemoved() throws {
        let support = try SupportDirectory(files: ["activity.jsonl", "activity-open.json", "hook-debug.jsonl", "debug", "lid-heartbeat", "lid-watchdog.sh", "remain.sock"])
        let report = uninstaller(try FakeHome(), support: support).removeEverything()
        #expect(Set(report.dataRemoved) == ["activity.jsonl", "activity-open.json", "hook-debug.jsonl", "debug", "lid-heartbeat", "lid-watchdog.sh"])
        #expect(!support.has("activity.jsonl"))
        #expect(!support.has("lid-watchdog.sh"))
    }

    @Test func theRunningAppsSocketIsLeftAlone() throws {
        let support = try SupportDirectory(files: ["remain.sock"])
        _ = uninstaller(try FakeHome(), support: support).removeEverything()
        #expect(support.has("remain.sock"))
    }

    @Test func otherFilesInTheSupportFolderAreNeverDeleted() throws {
        let support = try SupportDirectory(files: ["activity.jsonl", "notes-from-the-user.txt"])
        _ = uninstaller(try FakeHome(), support: support).removeEverything()
        #expect(support.has("notes-from-the-user.txt"))
    }

    @Test func runningItTwiceIsHarmless() throws {
        let fake = try FakeHome()
        try fake.makeDirectory(".claude")
        try fake.manager().install(.claudeCode)
        let support = try SupportDirectory(files: ["activity.jsonl"])
        let subject = uninstaller(fake, support: support)
        _ = subject.removeEverything()
        let second = subject.removeEverything()
        #expect(second.hooksRemoved.isEmpty)
        #expect(second.dataRemoved.isEmpty)
        #expect(second.errors.isEmpty)
    }

    @Test func aBrokenHooksFileDoesNotStopTheRest() throws {
        let fake = try FakeHome()
        try fake.makeDirectory(".claude")
        try fake.manager().install(.claudeCode)
        try fake.manager().install(.codex)
        try fake.write(".claude/settings.json", "{ broken") // now unreadable: Claude Code's removal must fail
        let support = try SupportDirectory(files: ["activity.jsonl"])

        let report = uninstaller(fake, support: support).removeEverything()

        #expect(!report.errors.isEmpty)
        #expect(report.hooksRemoved.contains(.codex)) // the other tool was still handled
        #expect(report.dataRemoved == ["activity.jsonl"]) // and so was the data
        #expect(try fake.read(".claude/settings.json") == "{ broken") // never overwritten
    }
}
