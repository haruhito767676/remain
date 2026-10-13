import Testing
@testable import RemainCore

@Suite struct IntegrationManagerTests {
    @Test func nothingDetectedOnAnEmptyHome() throws {
        let manager = try FakeHome().manager()
        for agent in AgentKind.integrable { #expect(manager.state(of: agent) == .notDetected) }
    }

    @Test func toolsAreDetectedByTheirDataFolders() throws {
        let fake = try FakeHome()
        try fake.makeDirectory(".claude")
        try fake.makeDirectory(".gemini/antigravity-ide")
        let manager = fake.manager()
        #expect(manager.state(of: .claudeCode) == .notInstalled)
        #expect(manager.state(of: .antigravity) == .notInstalled)
    }

    @Test func antigravityIsAlsoDetectedByItsApp() throws {
        let fake = try FakeHome()
        try fake.makeDirectory("Applications/Antigravity IDE.app")
        #expect(fake.manager().state(of: .antigravity) == .notInstalled)
    }

    @Test func installAndUninstallRoundTrip() throws {
        let fake = try FakeHome()
        try fake.makeDirectory(".claude")
        let manager = fake.manager()
        try manager.install(.claudeCode)
        #expect(manager.state(of: .claudeCode) == .installed)
        try manager.uninstall(.claudeCode)
        #expect(manager.state(of: .claudeCode) == .notInstalled)
    }

    @Test func installingCreatesTheConfigFileEvenWhenTheToolWasNotDetected() throws {
        let fake = try FakeHome()
        let manager = fake.manager()
        try manager.install(.antigravity)
        #expect(manager.state(of: .antigravity) == .installed) // present beats "not detected"
    }

    @Test func aMovedAppNeedsRepairAndRepairAllFixesBoth() throws {
        let fake = try FakeHome()
        try fake.makeDirectory(".claude")
        let old = fake.manager(executable: "/old/remain")
        try old.install(.claudeCode)
        try old.install(.antigravity)

        let moved = fake.manager(executable: "/new/remain")
        #expect(moved.state(of: .claudeCode) == .needsRepair)
        #expect(moved.state(of: .antigravity) == .needsRepair)
        #expect(Set(moved.repairAll()) == [.claudeCode, .antigravity])
        #expect(moved.state(of: .claudeCode) == .installed)
        #expect(moved.state(of: .antigravity) == .installed)
        #expect(moved.repairAll().isEmpty) // nothing left to do
    }

    @Test func repairLeavesHealthyAndMissingIntegrationsAlone() throws {
        let fake = try FakeHome()
        try fake.makeDirectory(".claude")
        let manager = fake.manager()
        #expect(manager.repairAll().isEmpty)
        #expect(manager.state(of: .claudeCode) == .notInstalled) // repair never installs by itself
    }

    @Test func codexIsNotOfferedYet() throws {
        #expect(!AgentKind.integrable.contains(.codex))
        #expect(throws: IntegrationError.self) { try FakeHome().manager().install(.codex) }
    }
}
