import AppKit
import Foundation

let output = URL(fileURLWithPath: "Assets/Installer", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for scale in [1, 2] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 760 * scale, pixelsHigh: 500 * scale,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

    func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight, hex: UInt32) {
        (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color(hex)
        ])
    }
    color(0xF5F6FC).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 760, height: 500)).fill()
    NSGradient(starting: color(0xEEF0FC), ending: color(0xF8F9FC))!
        .draw(in: NSBezierPath(rect: NSRect(x: 0, y: 0, width: 760, height: 500)), angle: -30)
    text("MACCLEAN", x: 47, y: 445, size: 12, weight: .semibold, hex: 0x5963C5)
    text("给开发，留点空间。", x: 44, y: 390, size: 32, weight: .semibold, hex: 0x29314A)
    text("把 MacClean 拖入「应用程序」，即可完成安装。", x: 47, y: 359, size: 13, weight: .regular, hex: 0x646D82)

    let panel = NSBezierPath(roundedRect: NSRect(x: 40, y: 112, width: 680, height: 214), xRadius: 25, yRadius: 25)
    NSColor.white.withAlphaComponent(0.88).setFill()
    panel.fill()
    color(0xE2E6F2).setStroke()
    panel.lineWidth = 1
    panel.stroke()
    for x: CGFloat in [220, 540] {
        color(0xF3F4FA).setFill()
        NSBezierPath(ovalIn: NSRect(x: x - 62, y: 191, width: 124, height: 124)).fill()
    }
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 342, y: 253))
    arrow.line(to: NSPoint(x: 418, y: 253))
    arrow.move(to: NSPoint(x: 406, y: 265))
    arrow.line(to: NSPoint(x: 418, y: 253))
    arrow.line(to: NSPoint(x: 406, y: 241))
    color(0x969ED4).setStroke()
    arrow.lineWidth = 2.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.stroke()

    text("01  拖动应用", x: 177, y: 131, size: 11, weight: .medium, hex: 0x646D82)
    text("02  放入此处", x: 497, y: 131, size: 11, weight: .medium, hex: 0x646D82)
    text("安装后，从「应用程序」打开 MacClean。", x: 47, y: 62, size: 12, weight: .regular, hex: 0x646D82)
    text("macOS 14+  ·  Apple Silicon & Intel", x: 47, y: 39, size: 11, weight: .regular, hex: 0x838AA0)
    NSGraphicsContext.restoreGraphicsState()
    let name = scale == 1 ? "background.png" : "background@2x.png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
