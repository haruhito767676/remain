import Foundation

public enum IntegrationState: Equatable, Sendable {
    /// The tool does not seem to be installed on this Mac.
    case notDetected
    case notInstalled
    case installed
    /// remAIn's hooks are in place but point at a different executable (the app was moved or replaced).
    case needsRepair
}

/// One place that knows, for every supported tool, where it lives, whether it is present and how to
/// connect remAIn to it.
public struct IntegrationManager: Sendable {
    public let executablePath: String
    private let home: URL
    private let applicationDirectories: [URL]

    public init(
        executablePath: String,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        applicationDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
    ) {
        self.executablePath = executablePath
        self.home = home
        self.applicationDirectories = applicationDirectories
    }

    // MARK: Locations

    public func configURL(of agent: AgentKind) -> URL? {
        switch agent {
        case .claudeCode: home.appendingPathComponent(".claude/settings.json")
        case .antigravity: home.appendingPathComponent(".gemini/config/hooks.json")
        case .codex, .command: nil
        }
    }

    private func claudeInstaller() -> HookInstaller {
        HookInstaller(settingsURL: configURL(of: .claudeCode)!, executablePath: executablePath)
    }

    private func antigravityInstaller() -> AntigravityHookInstaller {
        AntigravityHookInstaller(configURL: configURL(of: .antigravity)!, executablePath: executablePath)
    }

    // MARK: State

    /// Is the tool on this Mac? Judged by its data folder or app, never by running it.
    public func isDetected(_ agent: AgentKind) -> Bool {
        let fm = FileManager.default
        func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }
        switch agent {
        case .claudeCode:
            return exists(home.appendingPathComponent(".claude"))
        case .antigravity:
            return exists(home.appendingPathComponent(".gemini/antigravity-ide"))
                || exists(home.appendingPathComponent(".gemini/antigravity"))
                || applicationDirectories.contains { dir in
                    ["Antigravity IDE.app", "Antigravity.app"].contains { exists(dir.appendingPathComponent($0)) }
                }
        case .codex:
            return exists(home.appendingPathComponent(".codex"))
        case .command:
            return false
        }
    }

    public func state(of agent: AgentKind) -> IntegrationState {
        let installed: Bool, repair: Bool
        switch agent {
        case .claudeCode:
            let installer = claudeInstaller()
            (installed, repair) = (installer.isInstalled(), installer.needsRepair())
        case .antigravity:
            let installer = antigravityInstaller()
            (installed, repair) = (installer.isInstalled(), installer.needsRepair())
        case .codex, .command:
            return .notDetected
        }
        if installed { return repair ? .needsRepair : .installed }
        return isDetected(agent) ? .notInstalled : .notDetected
    }

    // MARK: Actions

    public func install(_ agent: AgentKind) throws {
        switch agent {
        case .claudeCode: try claudeInstaller().install()
        case .antigravity: try antigravityInstaller().install()
        case .codex, .command: throw IntegrationError.unsupported(agent)
        }
    }

    public func uninstall(_ agent: AgentKind) throws {
        switch agent {
        case .claudeCode: try claudeInstaller().uninstall()
        case .antigravity: try antigravityInstaller().uninstall()
        case .codex, .command: throw IntegrationError.unsupported(agent)
        }
    }

    /// Re-points every integration that has gone stale. Returns the ones it fixed.
    @discardableResult
    public func repairAll() -> [AgentKind] {
        AgentKind.integrable.filter { agent in
            guard state(of: agent) == .needsRepair else { return false }
            return (try? install(agent)) != nil
        }
    }
}

public enum IntegrationError: Error, CustomStringConvertible, Equatable {
    case unsupported(AgentKind)
    public var description: String {
        switch self {
        case .unsupported(let agent): "\(agent.displayName) is not supported yet."
        }
    }
}
