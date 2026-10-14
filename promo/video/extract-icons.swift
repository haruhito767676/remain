// Extracts the icons and symbols the intro video's desktop needs, from this Mac.
//
//   swift promo/video/extract-icons.swift promo/video/assets
//
// App icons are read from the installed apps with NSWorkspace, so they are always the real ones and
// are never committed to the repository (see .gitignore).
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets", isDirectory: true)
let icons = output.appendingPathComponent("icons", isDirectory: true)
let symbols = output.appendingPathComponent("symbols", isDirectory: true)
try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: symbols, withIntermediateDirectories: true)

func writePNG(_ image: NSImage, size: Int, to url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])!.write(to: url)
}

// App icons: name -> candidate paths (the first that exists wins).
let apps: [(String, [String])] = [
    ("finder", ["/System/Library/CoreServices/Finder.app"]),
    ("safari", ["/Applications/Safari.app", "/System/Cryptexes/App/System/Applications/Safari.app"]),
    ("mail", ["/System/Applications/Mail.app"]),
    ("notes", ["/System/Applications/Notes.app"]),
    ("calendar", ["/System/Applications/Calendar.app"]),
    ("settings", ["/System/Applications/System Settings.app"]),
    ("terminal", ["/System/Applications/Utilities/Terminal.app"]),
    ("chrome", ["/Applications/Google Chrome.app"]),
    ("vscode", ["/Applications/Visual Studio Code.app"]),
    ("chatgpt", ["/Applications/ChatGPT.app"]),
    ("antigravity", ["/Applications/Antigravity IDE.app"]),
    ("remain", [NSHomeDirectory() + "/Applications/remAIn.app"]),
]
for (name, paths) in apps {
    guard let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { print("missing app icon: \(name)"); continue }
    writePNG(NSWorkspace.shared.icon(forFile: path), size: 512, to: icons.appendingPathComponent("\(name).png"))
}

// System icons.
let core = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/"
for (name, file) in [("folder", "GenericFolderIcon.icns"), ("trash", "TrashIcon.icns")] {
    if let image = NSImage(contentsOfFile: core + file) { writePNG(image, size: 512, to: icons.appendingPathComponent("\(name).png")) }
    else { print("missing system icon: \(name)") }
}

// SF Symbols, tinted white, for the menu bar. (They are the symbols the real app shows.)
let symbolNames: [(String, String)] = [
    ("sparkles", "sparkles"), ("moon", "moon.zzz"), ("hourglass", "hourglass"), ("cup", "cup.and.saucer.fill"),
    ("wifi", "wifi"), ("search", "magnifyingglass"), ("controls", "switch.2"),
]
for (name, symbol) in symbolNames {
    guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else { print("missing symbol: \(symbol)"); continue }
    let config = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular).applying(.init(paletteColors: [.white]))
    guard let image = base.withSymbolConfiguration(config) else { continue }
    let size = image.size
    let scale = 3.0
    let w = Int(size.width * scale) + 8, h = Int(size.height * scale) + 8
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 4, y: 4, width: size.width * scale, height: size.height * scale))
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])!.write(to: symbols.appendingPathComponent("\(name).png"))
}
print("Wrote icons to \(output.path)")
