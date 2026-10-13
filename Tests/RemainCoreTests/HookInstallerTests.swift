import Testing
@testable import RemainCore

@Suite struct HookInstallerTests {
    @Test func installsIntoMissingFile() throws {
        let installer = try makeInstaller()
        #expect(!installer.isInstalled())
        try installer.install()
        #expect(installer.isInstalled())
    }

    @Test func preservesForeignSettingsAndHooks() throws {
        let installer = try makeInstaller(existing: """
        {"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}
        """)
        try installer.install()
        let root = try readSettings(installer)
        #expect(root["model"] as? String == "opus")
        let stop = (root["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        #expect(stop.count == 2)
    }

    @Test func installIsIdempotent() throws {
        let installer = try makeInstaller()
        try installer.install()
        try installer.install()
        let hooks = try readSettings(installer)["hooks"] as! [String: Any]
        #expect((hooks["Stop"] as! [Any]).count == 1)
    }

    @Test func uninstallRemovesOnlyRemain() throws {
        let installer = try makeInstaller(existing: """
        {"hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}
        """)
        try installer.install()
        try installer.uninstall()
        #expect(!installer.isInstalled())
        let hooks = try readSettings(installer)["hooks"] as! [String: Any]
        #expect((hooks["Stop"] as! [Any]).count == 1)
        #expect(hooks["UserPromptSubmit"] == nil)
    }

    @Test func refusesToOverwriteBrokenJSON() throws {
        let installer = try makeInstaller(existing: "{ not json")
        #expect(throws: (any Error).self) { try installer.install() }
        #expect(try rawSettings(installer) == "{ not json")
    }

    @Test func quotesPathsWithSpaces() {
        #expect(HookInstaller.shellQuote("/a b/remain") == "'/a b/remain'")
        #expect(HookInstaller.isRemainCommand("'/a b/remain' hook"))
        #expect(!HookInstaller.isRemainCommand("say done"))
    }
}
