// Foundation-dependent helpers live here so that test files only need `import Testing`.
// (Importing both in one file requires the `_Testing_Foundation` overlay, which is missing
// from some Command Line Tools installs.)
import Foundation
@testable import RemainCore

let t0 = Date(timeIntervalSince1970: 1_000_000)

func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

func event(_ kind: AgentEvent.Kind, _ id: String = "a") -> AgentEvent {
    AgentEvent(sessionID: id, kind: kind)
}

func decodeHook(_ json: String) throws -> HookPayload {
    try JSONDecoder().decode(HookPayload.self, from: Data(json.utf8))
}

func makeInstaller(existing: String? = nil) throws -> HookInstaller {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("settings.json")
    if let existing { try existing.write(to: url, atomically: true, encoding: .utf8) }
    return HookInstaller(settingsURL: url, executablePath: "/Applications/remAIn.app/Contents/Helpers/remain")
}

func readSettings(_ installer: HookInstaller) throws -> [String: Any] {
    let data = try Data(contentsOf: installer.settingsURL)
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
}

func rawSettings(_ installer: HookInstaller) throws -> String {
    try String(contentsOf: installer.settingsURL, encoding: .utf8)
}

func decodeSettings(_ json: String) throws -> WakeSettings {
    try JSONDecoder().decode(WakeSettings.self, from: Data(json.utf8))
}
