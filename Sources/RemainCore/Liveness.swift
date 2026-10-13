import Foundation
import Darwin

// MARK: - Finding the Claude Code process

public enum ProcessTree {
    /// Names under which Claude Code runs (CLI, VS Code extension binary, npm `claude.exe`).
    static let claudeNames: Set<String> = ["claude", "claude.exe"]

    /// The nearest ancestor of `pid` that is a Claude Code process.
    /// A hook runs as `claude -> sh -> remain hook`, so this is normally two levels up.
    public static func claudeAncestor(of pid: Int32 = getppid()) -> Int32? {
        var current = pid
        for _ in 0..<8 {
            guard current > 1 else { return nil }
            if let name = executableName(of: current), claudeNames.contains(name) { return current }
            guard let parent = parent(of: current) else { return nil }
            current = parent
        }
        return nil
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
    func scanTranscript(path: String, from offset: UInt64) -> TranscriptScan
}

public struct SystemSessionProbe: SessionProbing {
    public init() {}

    public func isAlive(pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    public func scanTranscript(path: String, from offset: UInt64) -> TranscriptScan {
        TranscriptScanner.scan(path: path, from: offset)
    }
}
