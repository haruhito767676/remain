// Adds the soft drop shadow a macOS window has to a screenshot that was captured without it
// (screencapture -o), so windows do not melt into a white or dark page.
//
//   swift promo/shadow.swift in.png out.png
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 3, let source = NSImage(contentsOfFile: args[1]),
      let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("usage: shadow.swift <in.png> <out.png>\n".utf8))
    exit(1)
}

let pad = 72                 // pixels around the window (the images are 2x)
let width = cgImage.width + pad * 2, height = cgImage.height + pad * 2
let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
context.setShadow(offset: CGSize(width: 0, height: -22), blur: 46, color: CGColor(gray: 0, alpha: 0.38))
context.draw(cgImage, in: CGRect(x: pad, y: pad, width: cgImage.width, height: cgImage.height))
guard let result = context.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: result)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
