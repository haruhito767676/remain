import Foundation
import Darwin

// MARK: - Finding the Claude Code process

public enum ProcessTree {
    /// Names under which Claude Code runs (CLI, VS Code extension binary, npm `claude.exe`).
    static let claudeNames: Set<String> = ["claude", "claude.exe"]

    /// The nearest ancestor of `pid` that is a Claude Code process.
    /// A hook runs as `claude -> sh -> remain hook`, so this is normally two levels up.
    public static func claudeAncestor(of pid: Int32 = getppid()) -> Int32? {
        agentAncestor(for: .claudeCode, of: pid)
    }

    /// The nearest ancestor of `pid` that belongs to the given tool.
    public static func agentAncestor(for agent: AgentKind, of pid: Int32 = getppid()) -> Int32? {
        ancestors(of: pid).first { agent.ownsProcess(named: $0.name) }?.pid
    }

    /// Process names from `pid` upwards (used by the matcher and by the debug log).
    public static func ancestors(of pid: Int32 = getppid(), limit: Int = 10) -> [(pid: Int32, name: String)] {
        var result: [(pid: Int32, name: String)] = []
        var current = pid
        for _ in 0..<limit {
            guard current > 1 else { break }
            result.append((current, executableName(of: current) ?? "?"))
            guard let parent = parent(of: current) else { break }
            current = parent
        }
        return result
    }

    static func parent(of pid: Int32) -> Int32? {
        var info = proc_bsdinfo()
        let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        return size > 0 ? Int32(info.pbi_ppid) : nil
    }

    static func executableName(of pid: Int32) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let path = String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        return URL(fileURLWithPath: path).lastPathComponent
    }
}

// MARK: - Transcript scanning

public struct TranscriptScan: Equatable, Sendable {
    /// Offset just after the last complete line that was examined.
    public var newOffset: UInt64
    public var interrupted: Bool

    public init(newOffset: UInt64, interrupted: Bool) {
        self.newOffset = newOffset
        self.interrupted = interrupted
    }
}

/// Reads the Claude Code conversation log (JSON Lines) to notice interruptions,
/// which do not trigger a `Stop` hook.
public enum TranscriptScanner {
    static let marker = "[Request interrupted by user"

    public static func fileSize(atPath path: String) -> UInt64? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? UInt64) ?? nil
    }

    /// True if any complete line is a *user* message whose text starts with the interruption marker.
    /// Only user entries count: the marker text may also appear in assistant output or tool results.
    public static func containsInterruption(in data: Data) -> Bool {
        let needle = Data(marker.utf8)
        for line in data.split(separator: UInt8(ascii: "\n")) {
            let bytes = Data(line)
            guard bytes.range(of: needle) != nil,
                  let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  object["type"] as? String == "user",
                  let message = object["message"] as? [String: Any] else { continue }
            switch message["content"] {
            case let text as String:
                if text.hasPrefix(marker) { return true }
            case let items as [[String: Any]]:
                if items.contains(where: { ($0["type"] as? String) == "text" && ($0["text"] as? String)?.hasPrefix(marker) == true }) {
                    return true
                }
            default:
                break
            }
        }
        return false
    }

    /// Scans the part of the file that was appended after `offset`.
    public static func scan(path: String, from offset: UInt64, maxBytes: Int = 8 << 20) -> TranscriptScan {
        let unchanged = TranscriptScan(newOffset: offset, interrupted: false)
        guard let handle = FileHandle(forReadingAtPath: path) else { return unchanged }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return unchanged }
        if size < offset { return TranscriptScan(newOffset: size, interrupted: false) } // truncated / rotated
        if size == offset { return unchanged }
        guard (try? handle.seek(toOffset: offset)) != nil,
              let data = try? handle.read(upToCount: min(Int(size - offset), maxBytes)),
              let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return unchanged }
        let complete = data.prefix(through: lastNewline) // never judge a half-written line
        return TranscriptScan(
            newOffset: offset + UInt64(complete.count),
            interrupted: containsInterruption(in: complete)
        )
    }
}

// MARK: - Probe abstraction

public protocol SessionProbing: Sendable {
    func isAlive(pid: Int32) -> Bool
    /// Alive *and still that tool*: a recycled process id must not keep a finished session going.
    func isAlive(pid: Int32, agent: AgentKind) -> Bool
    func scanTranscript(path: String, from offset: UInt64) -> TranscriptScan
}

extension SessionProbing {
    public func isAlive(pid: Int32, agent: AgentKind) -> Bool { isAlive(pid: pid) }
}

public struct SystemSessionProbe: SessionProbing {
    public init() {}

    public func isAlive(pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    public func isAlive(pid: Int32, agent: AgentKind) -> Bool {
        guard isAlive(pid: pid) else { return false }
        // `remain run` watches the command itself, whatever it is called. For the tools, the process
        // we remembered must still carry the tool's name (unknown when it cannot be inspected).
        guard agent != .command, let name = ProcessTree.executableName(of: pid) else { return true }
        return agent.ownsProcess(named: name)
    }

    public func scanTranscript(path: String, from offset: UInt64) -> TranscriptScan {
        TranscriptScanner.scan(path: path, from: offset)
    }
}
