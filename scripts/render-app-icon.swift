import AppKit
import Foundation

// Reuse the menu bar's exact controller mask; only the tint and background differ.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let markURL = root.appendingPathComponent("Resources/Branding/dualshock4-mark.png")
guard let mark = NSImage(contentsOf: markURL) else { fatalError("Missing controller mark") }
let size = NSSize(width: 1024, height: 1024)
func bitmap() -> NSBitmapImageRep {
  NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}
let whiteMark = bitmap()
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: whiteMark)
mark.draw(in: NSRect(origin: .zero, size: size))
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill(using: .sourceIn)
NSGraphicsContext.restoreGraphicsState()
let foreground = NSImage(size: size)
foreground.addRepresentation(whiteMark)
let result = bitmap()
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: result)
let tile = NSRect(x: 32, y: 32, width: 960, height: 960)
let path = NSBezierPath(roundedRect: tile, xRadius: 216, yRadius: 216)
NSGradient(
  starting: NSColor(srgbRed: 0.035, green: 0.09, blue: 0.25, alpha: 1),
  ending: NSColor(srgbRed: 0.08, green: 0.36, blue: 0.85, alpha: 1))!
  .draw(in: path, angle: 90)
foreground.draw(in: NSRect(x: 112, y: 112, width: 800, height: 800))
NSGraphicsContext.restoreGraphicsState()
try result.representation(using: .png, properties: [:])!
  .write(to: root.appendingPathComponent("Resources/Branding/logo.png"))
