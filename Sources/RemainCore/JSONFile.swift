import Foundation

/// Reads and writes another tool's JSON settings file without ever clobbering what we cannot parse.
enum JSONFile {
    struct Invalid: Error, CustomStringConvertible {
        let reason: String
        var description: String { "Could not parse \(reason)" }
    }

    /// A missing or empty file is an empty object; anything unparseable throws instead of being overwritten.
    static func load(_ url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x09 || $0 == 0x0D }) { return [:] }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Invalid(reason: "\(url.lastPathComponent): top level is not an object")
            }
            return object
        } catch let error as Invalid {
            throw error
        } catch {
            throw Invalid(reason: "\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Atomic write; the original is copied to `<name>.remain-backup` once.
    static func save(_ root: [String: Any], to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: url.path) {
            let backup = url.appendingPathExtension("remain-backup")
            if !fm.fileExists(atPath: backup.path) { try fm.copyItem(at: url, to: backup) }
        }
        let data = try JSONSerialization.data(
            withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
    }
}
