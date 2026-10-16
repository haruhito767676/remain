import Foundation

/// Runs one shell command with administrator rights: macOS shows its own password dialog.
enum AdministratorShell {
    enum Failure: Error, Equatable {
        case cancelled
        case failed(String)
    }

    static func run(_ command: String) throws {
        let result = Shell.run("/usr/bin/osascript", ["-e", LidSupport.adminAppleScript(command)])
        guard result.status == 0 else {
            if result.output.contains("-128") || result.output.localizedCaseInsensitiveContains("canceled") {
                throw Failure.cancelled
            }
            throw Failure.failed(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

public enum CommandLineToolState: Equatable, Sendable {
    case notInstalled
    case installed
    /// Our link, but the app has moved or the link is broken.
    case needsRepair
    /// Something that is not ours is at that path: left alone.
    case blocked
}

public enum CommandLineToolError: Error, CustomStringConvertible, Equatable {
    case cancelled
    case blocked
    case unsafePath
    case failed(String)

    public var description: String {
        switch self {
        case .cancelled: "Setup was cancelled."
        case .blocked: "Another file named remain is already there."
        case .unsafePath: "The path contains unexpected characters."
        case .failed(let message): message
        }
    }
}

/// Puts the `remain` command where every Terminal finds it: a link at /usr/local/bin/remain pointing into the app.
/// It asks for the administrator password only when the folder is not writable by the user.
public struct CommandLineTool: Sendable {
    public static let defaultLink = URL(fileURLWithPath: "/usr/local/bin/remain")

    private let helper: URL
    private let link: URL

    public init(helper: URL, link: URL = CommandLineTool.defaultLink) {
        self.helper = helper
        self.link = link
    }

    public func state() -> CommandLineToolState {
        let fm = FileManager.default
        guard (try? fm.attributesOfItem(atPath: link.path)) != nil else { return .notInstalled } // does not follow the link
        guard let destination = try? fm.destinationOfSymbolicLink(atPath: link.path) else { return .blocked } // a plain file
        let target = URL(fileURLWithPath: destination, relativeTo: link.deletingLastPathComponent()).standardizedFileURL.path
        if target == helper.standardizedFileURL.path {
            return fm.isExecutableFile(atPath: helper.path) ? .installed : .needsRepair
        }
        return Self.looksLikeOurs(target) ? .needsRepair : .blocked
    }

    static func looksLikeOurs(_ path: String) -> Bool {
        path.hasSuffix("/remAIn.app/Contents/Helpers/remain")
    }

    static func isSafe(_ path: String) -> Bool {
        !path.isEmpty && !path.contains("'") && !path.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    public func install() throws {
        switch state() {
        case .blocked: throw CommandLineToolError.blocked
        case .installed: return
        case .notInstalled, .needsRepair: break
        }
        guard Self.isSafe(helper.path), Self.isSafe(link.path) else { throw CommandLineToolError.unsafePath }
        let fm = FileManager.default
        let directory = link.deletingLastPathComponent()
        if fm.isWritableFile(atPath: directory.path) {
            try? fm.removeItem(at: link) // only ever our own broken link: `.blocked` was refused above
            do {
                try fm.createSymbolicLink(at: link, withDestinationURL: helper)
                return
            } catch {
                // fall through to the administrator route
            }
        }
        try runAsAdmin("/bin/mkdir -p '\(directory.path)' && /bin/ln -sfn '\(helper.path)' '\(link.path)'")
    }

    public func uninstall() throws {
        switch state() {
        case .notInstalled: return
        case .blocked: throw CommandLineToolError.blocked
        case .installed, .needsRepair: break
        }
        guard Self.isSafe(link.path) else { throw CommandLineToolError.unsafePath }
        if (try? FileManager.default.removeItem(at: link)) != nil { return }
        try runAsAdmin("/bin/rm -f '\(link.path)'")
    }

    private func runAsAdmin(_ command: String) throws {
        do {
            try AdministratorShell.run(command)
        } catch AdministratorShell.Failure.cancelled {
            throw CommandLineToolError.cancelled
        } catch AdministratorShell.Failure.failed(let message) {
            throw CommandLineToolError.failed(message)
        }
    }
}
