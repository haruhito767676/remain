#!/usr/bin/env swift
// Draws the remAIn app icon and writes Resources/AppIcon.icns.
//
//   swift scripts/make-icon.swift [output.icns]
//
// The icon is drawn from scratch with CoreGraphics (no SF Symbols: Apple's license does not
// allow them in app icons). Concept: a sleeping moon held inside a task-progress ring whose
// bright head carries an AI sparkle, i.e. "stays awake while the task runs".
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
}

/// Apple-style continuous-corner icon shape (a superellipse).
func squircle(_ rect: CGRect, exponent n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    for i in 0...360 {
        let t = CGFloat(i) / 360 * 2 * .pi
        let c = cos(t), s = sin(t)
        let point = CGPoint(x: rect.midX + a * copysign(pow(abs(c), 2 / n), c),
                            y: rect.midY + b * copysign(pow(abs(s), 2 / n), s))
        i == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

/// Four-pointed star with concave sides.
func sparkle(at c: CGPoint, radius R: CGFloat, pinch: CGFloat = 0.13) -> CGPath {
    let path = CGMutablePath(), k = R * pinch
    path.move(to: CGPoint(x: c.x, y: c.y + R))
    path.addQuadCurve(to: CGPoint(x: c.x + R, y: c.y), control: CGPoint(x: c.x + k, y: c.y + k))
    path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - R), control: CGPoint(x: c.x + k, y: c.y - k))
    path.addQuadCurve(to: CGPoint(x: c.x - R, y: c.y), control: CGPoint(x: c.x - k, y: c.y - k))
    path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + R), control: CGPoint(x: c.x - k, y: c.y + k))
    path.closeSubpath()
    return path
}

func fill(_ ctx: CGContext, _ path: CGPath, _ color: CGColor, glow: CGColor? = nil, blur: CGFloat = 40) {
    ctx.saveGState()
    if let glow { ctx.setShadow(offset: .zero, blur: blur, color: glow) }
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath()
    ctx.restoreGState()
}

func drawIcon(_ ctx: CGContext) {
    // Background tile with the standard 100pt margin of the 1024 icon grid.
    let tile = squircle(CGRect(x: 100, y: 100, width: 824, height: 824))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.38))
    ctx.addPath(tile)
    ctx.setFillColor(rgb(0x12153F))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0x5A3FBF), rgb(0x12153F)]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.drawLinearGradient(gradient([rgb(0xFFFFFF, 0.20), rgb(0xFFFFFF, 0)]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])
    ctx.restoreGState()

    // The sleeping moon: a disc with an offset disc cut out of it.
    ctx.saveGState()
    ctx.addPath(CGPath(ellipseIn: CGRect(x: 392, y: 392, width: 240, height: 240), transform: nil))
    ctx.clip()
    ctx.addRect(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.addPath(CGPath(ellipseIn: CGRect(x: 462, y: 452, width: 210, height: 210), transform: nil))
    ctx.clip(using: .evenOdd)
    ctx.setShadow(offset: .zero, blur: 40, color: rgb(0xFFE9A8, 0.5))
    ctx.drawLinearGradient(gradient([rgb(0xFFF8E3), rgb(0xFFD98A)]),
                           start: CGPoint(x: 400, y: 632), end: CGPoint(x: 620, y: 392), options: [])
    ctx.restoreGState()

    // The task-progress ring: a bright head at the upper right, a tail fading out counter-clockwise.
    let center = CGPoint(x: 512, y: 512), radius: CGFloat = 270
    let head = 52 * CGFloat.pi / 180, span = 290 * CGFloat.pi / 180
    // The ring is computed per pixel (angle + distance from the centre): its width tapers and its
    // opacity fades along the angle, which stacked strokes cannot do without visible seams.
    let cyan: (CGFloat, CGFloat, CGFloat) = (0x7B, 0xE8, 0xFF)
    let side = Int(size)
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    for row in 0..<side {
        let dy = (size - 0.5 - CGFloat(row)) - center.y
        for column in 0..<side {
            let dx = (CGFloat(column) + 0.5) - center.x
            var delta = atan2(dy, dx) - head
            while delta < 0 { delta += 2 * .pi }
            let t = delta / span
            guard t <= 1 else { continue }
            let ringWidth = 66 * (1 - 0.55 * t)
            let distance = abs((dx * dx + dy * dy).squareRoot() - radius)
            let coverage = min(max(0.5 + (ringWidth / 2 - distance), 0), 1) // 1px feathered edge
            guard coverage > 0 else { continue }
            let opacity = t < 0.4 ? 0.97 - (0.97 - 0.55) * (t / 0.4) : 0.55 * (1 - (t - 0.4) / 0.6)
            let alpha = coverage * opacity
            let offset = (row * side + column) * 4
            pixels[offset] = UInt8(cyan.0 * alpha)
            pixels[offset + 1] = UInt8(cyan.1 * alpha)
            pixels[offset + 2] = UInt8(cyan.2 * alpha)
            pixels[offset + 3] = UInt8(255 * alpha)
        }
    }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let ringImage = CGImage(
        width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4, space: space,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
        decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    ctx.draw(ringImage, in: CGRect(x: 0, y: 0, width: size, height: size))

    // Rounded head of the ring.
    let headPoint = CGPoint(x: center.x + radius * cos(head), y: center.y + radius * sin(head))
    fill(ctx, CGPath(ellipseIn: CGRect(x: headPoint.x - 33, y: headPoint.y - 33, width: 66, height: 66), transform: nil), rgb(0x7BE8FF, 0.97))

    // The AI sparkle riding on the head of the ring.
    let tip = CGPoint(x: center.x + radius * cos(head), y: center.y + radius * sin(head))
    fill(ctx, sparkle(at: tip, radius: 100), rgb(0xFFFFFF), glow: rgb(0x9FEFFF), blur: 45)
}

// MARK: - Rendering and packaging

func makeContext(_ pixels: Int) -> CGContext {
    CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}

let master = makeContext(Int(size))
drawIcon(master)
let masterImage = master.makeImage()!

func scaled(_ pixels: Int) -> CGImage {
    if pixels == Int(size) { return masterImage }
    let ctx = makeContext(pixels)
    ctx.interpolationQuality = .high
    ctx.draw(masterImage, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return ctx.makeImage()!
}

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("remAIn-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

// Names and pixel sizes required by `iconutil`.
let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in entries {
    try writePNG(scaled(pixels), to: iconset.appendingPathComponent("\(name).png"))
}

try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output.path)")
