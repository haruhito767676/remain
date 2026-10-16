import Testing
@testable import RemainCore

@Suite struct CommandLineToolTests {
    @Test func installsALinkWithoutAPasswordWhereTheFolderIsWritable() throws {
        let r = try makeCLIRig(); defer { r.cleanup() }
        let tool = r.tool(r.helperA)
        #expect(tool.state() == .notInstalled)
        try tool.install()
        #expect(tool.state() == .installed)
        try tool.install() // twice is fine
        #expect(tool.state() == .installed)
    }

    @Test func aMovedAppNeedsRepairAndInstallingRepairsIt() throws {
        let r = try makeCLIRig(); defer { r.cleanup() }
        try r.tool(r.helperA).install()
        let moved = r.tool(r.helperB) // the app is now somewhere else
        #expect(moved.state() == .needsRepair)
        try moved.install()
        #expect(moved.state() == .installed)
    }

    @Test func aBrokenLinkToTheOldAppNeedsRepair() throws {
        let r = try makeCLIRig(); defer { r.cleanup() }
        let tool = r.tool(r.helperA)
        try tool.install()
        try r.delete(r.helperA)
        #expect(tool.state() == .needsRepair)
    }

    @Test func neverTouchesAFileThatIsNotOurs() throws {
        let r = try makeCLIRig(); defer { r.cleanup() }
        try r.putFileAtLink("mine")
        let tool = r.tool(r.helperA)
        #expect(tool.state() == .blocked)
        #expect(throws: CommandLineToolError.blocked) { try tool.install() }
        #expect(throws: CommandLineToolError.blocked) { try tool.uninstall() }
        #expect(try r.linkContents() == "mine")

        try r.removeLink()
        try r.putForeignLink() // someone else's link
        #expect(tool.state() == .blocked)
        #expect(throws: CommandLineToolError.blocked) { try tool.install() }
    }

    @Test func uninstallRemovesOnlyOurLink() throws {
        let r = try makeCLIRig(); defer { r.cleanup() }
        let tool = r.tool(r.helperA)
        try tool.uninstall() // nothing there: fine
        try tool.install()
        try tool.uninstall()
        #expect(tool.state() == .notInstalled)
        #expect(r.exists(r.helperA))
    }

    @Test func refusesPathsThatCouldBreakTheShellCommand() {
        #expect(CommandLineTool.isSafe("/Applications/remAIn.app/Contents/Helpers/remain"))
        #expect(!CommandLineTool.isSafe("/tmp/it's/remain"))
        #expect(!CommandLineTool.isSafe("/tmp/a\nb"))
    }
}
