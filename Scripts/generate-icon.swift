import AppKit
import Foundation

// A Mac display and a sweeping brush communicate the app's purpose at small sizes.
func drawMark(in context: CGContext, pixels: Int) {
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.2)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    let tile = NSBezierPath(roundedRect: NSRect(x: 58, y: 58, width: 908, height: 908), xRadius: 210, yRadius: 210)
    NSGradient(starting: color(0x7985E4), ending: color(0x454FAD))!.draw(in: tile, angle: -80)
    NSShadow().set()

    // The stand sits behind the display, giving it an unmistakable desktop silhouette.
    color(0xC8D1F0).setFill()
    let stand = NSBezierPath()
    stand.move(to: NSPoint(x: 463, y: 382))
    stand.line(to: NSPoint(x: 555, y: 382))
    stand.line(to: NSPoint(x: 578, y: 251))
    stand.line(to: NSPoint(x: 439, y: 251))
    stand.close()
    stand.fill()
    color(0xEEF1FF).setFill()
    NSBezierPath(roundedRect: NSRect(x: 351, y: 225, width: 316, height: 37), xRadius: 18, yRadius: 18).fill()

    shadow.shadowColor = color(0x232B72).withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -15)
    shadow.set()
    let display = NSBezierPath(roundedRect: NSRect(x: 181, y: 346, width: 662, height: 430), xRadius: 52, yRadius: 52)
    NSGradient(starting: color(0xFFFFFF), ending: color(0xDCE3F8))!.draw(in: display, angle: -90)
    NSShadow().set()
    let screen = NSBezierPath(roundedRect: NSRect(x: 205, y: 411, width: 614, height: 341), xRadius: 31, yRadius: 31)
    NSGradient(starting: color(0xA8BAF4), ending: color(0x687BD0))!.draw(in: screen, angle: -45)

    // A long handle, ferrule and fanned bristles read as a cleaning brush.
    shadow.shadowColor = color(0x283168).withAlphaComponent(0.2)
    shadow.shadowBlurRadius = 15
    shadow.shadowOffset = NSSize(width: 0, height: -7)
    shadow.set()
    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: 533, y: 533))
    handle.line(to: NSPoint(x: 755, y: 800))
    handle.lineWidth = 46
    handle.lineCapStyle = .round
    color(0xFFF5DA).setStroke()
    handle.stroke()
    NSShadow().set()
    let bristles = NSBezierPath()
    bristles.move(to: NSPoint(x: 493, y: 566))
    bristles.line(to: NSPoint(x: 584, y: 489))
    bristles.line(to: NSPoint(x: 486, y: 341))
    bristles.curve(to: NSPoint(x: 358, y: 449), controlPoint1: NSPoint(x: 433, y: 353), controlPoint2: NSPoint(x: 387, y: 393))
    bristles.close()
    NSGradient(starting: color(0xFFE6A0), ending: color(0xF4B94F))!.draw(in: bristles, angle: -65)
    context.saveGState()
    bristles.addClip()
    color(0xD89B36).withAlphaComponent(0.58).setStroke()
    for offset: CGFloat in [-58, -25, 8, 41, 74] {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 505 + offset, y: 493 - offset * 0.84))
        line.line(to: NSPoint(x: 402 + offset, y: 372 - offset * 0.84))
        line.lineWidth = 5
        line.lineCapStyle = .round
        line.stroke()
    }
    context.restoreGState()
    let ferrule = NSBezierPath()
    ferrule.move(to: NSPoint(x: 488, y: 574))
    ferrule.line(to: NSPoint(x: 593, y: 485))
    ferrule.line(to: NSPoint(x: 572, y: 456))
    ferrule.line(to: NSPoint(x: 463, y: 549))
    ferrule.close()
    color(0xFFF5DB).setFill()
    ferrule.fill()

    func sparkle(x: CGFloat, y: CGFloat, radius: CGFloat) {
        let path = NSBezierPath()
        let inset = radius * 0.23
        path.move(to: NSPoint(x: x, y: y + radius))
        for (dx, dy) in [(inset, inset), (radius, 0), (inset, -inset), (0, -radius), (-inset, -inset), (-radius, 0), (-inset, inset)] {
            path.line(to: NSPoint(x: x + dx, y: y + dy))
        }
        path.close()
        NSColor.white.setFill()
        path.fill()
    }
    sparkle(x: 314, y: 652, radius: 60)
    sparkle(x: 390, y: 708, radius: 25)
}

func png(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawMark(in: NSGraphicsContext.current!.cgContext, pixels: pixels)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(size)@\(scale)x.png"
        try png(pixels: size * scale).write(to: directory.appendingPathComponent(filename))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
    }
}
let info: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("Contents.json"))
let mark = URL(fileURLWithPath: "Assets.xcassets/MacCleanMark.imageset")
try FileManager.default.createDirectory(at: mark, withIntermediateDirectories: true)
final class MarkView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        drawMark(in: NSGraphicsContext.current!.cgContext, pixels: 1024)
    }
}
let markView = MarkView(frame: NSRect(x: 0, y: 0, width: 1024, height: 1024))
try markView.dataWithPDF(inside: markView.bounds).write(to: mark.appendingPathComponent("mark.pdf"))
try? FileManager.default.removeItem(at: mark.appendingPathComponent("mark.png"))
try Data(#"{"images":[{"idiom":"universal","filename":"mark.pdf"}],"info":{"author":"xcode","version":1},"properties":{"preserves-vector-representation":true}}"#.utf8)
    .write(to: mark.appendingPathComponent("Contents.json"))
