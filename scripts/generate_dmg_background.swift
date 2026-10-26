import AppKit
import Foundation

let logicalWidth: CGFloat = 660
let logicalHeight: CGFloat = 400
let scale: CGFloat = 2
let pixelWidth = Int(logicalWidth * scale)
let pixelHeight = Int(logicalHeight * scale)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelWidth,
    pixelsHigh: pixelHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create bitmap")
}

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create graphics context")
}
NSGraphicsContext.current = context
context.cgContext.scaleBy(x: scale, y: scale)
context.imageInterpolation = .high
context.cgContext.setShouldAntialias(true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

let bounds = NSRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight)
let background = NSGradient(colors: [
    color(0x062F3B),
    color(0x084A55),
    color(0x0A3C4A)
])!
background.draw(in: bounds, angle: -35)

NSGraphicsContext.saveGraphicsState()
let glowTop = NSGradient(colors: [
    color(0x2DD4BF, alpha: 0.18),
    color(0x2DD4BF, alpha: 0)
])!
glowTop.draw(
    fromCenter: NSPoint(x: 20, y: 390),
    radius: 0,
    toCenter: NSPoint(x: 20, y: 390),
    radius: 510,
    options: []
)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
let glowBottom = NSGradient(colors: [
    color(0xF97316, alpha: 0.12),
    color(0xF97316, alpha: 0)
])!
glowBottom.draw(
    fromCenter: NSPoint(x: 610, y: 30),
    radius: 0,
    toCenter: NSPoint(x: 610, y: 30),
    radius: 420,
    options: []
)
NSGraphicsContext.restoreGraphicsState()

func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
    return NSFont(descriptor: descriptor, size: size) ?? base
}

func drawText(
    _ text: String,
    at point: NSPoint,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    width: CGFloat? = nil
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: 0.1
    ]
    if let width {
        let rect = NSRect(x: point.x, y: point.y, width: width, height: font.pointSize * 2.2)
        (text as NSString).draw(in: rect, withAttributes: attributes)
    } else {
        (text as NSString).draw(at: point, withAttributes: attributes)
    }
}

drawText(
    "Clipboard Manager",
    at: NSPoint(x: 42, y: 331),
    font: roundedFont(size: 27, weight: .bold),
    color: color(0xF2FFFD)
)

drawText(
    "Local-first history, snippets, OCR search, and instant paste.",
    at: NSPoint(x: 44, y: 308),
    font: roundedFont(size: 11, weight: .medium),
    color: color(0xD5F7F2, alpha: 0.62)
)

let badgeRect = NSRect(x: 508, y: 329, width: 112, height: 24)
let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 12, yRadius: 12)
color(0xFFFFFF, alpha: 0.075).setFill()
badge.fill()
color(0xFFFFFF, alpha: 0.10).setStroke()
badge.lineWidth = 1
badge.stroke()
drawText(
    "v2.0 · Universal",
    at: NSPoint(x: badgeRect.minX, y: badgeRect.minY + 6),
    font: roundedFont(size: 9.5, weight: .semibold),
    color: color(0xD5F7F2, alpha: 0.70),
    alignment: .center,
    width: badgeRect.width
)

let arrowY: CGFloat = 210
let arrowStart = NSPoint(x: 253, y: arrowY)
let arrowEnd = NSPoint(x: 397, y: arrowY)
let arrow = NSBezierPath()
arrow.move(to: arrowStart)
arrow.line(to: arrowEnd)
arrow.setLineDash([5, 7], count: 2, phase: 0)
color(0xFFFFFF, alpha: 0.30).setStroke()
arrow.lineWidth = 1.8
arrow.lineCapStyle = .round
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: arrowEnd.x - 9, y: arrowEnd.y + 6))
arrowHead.line(to: NSPoint(x: arrowEnd.x, y: arrowEnd.y))
arrowHead.line(to: NSPoint(x: arrowEnd.x - 9, y: arrowEnd.y - 6))
color(0xFFFFFF, alpha: 0.45).setStroke()
arrowHead.lineWidth = 1.9
arrowHead.lineCapStyle = .round
arrowHead.lineJoinStyle = .round
arrowHead.stroke()

let hint = "Drag Clipboard Manager to Applications to install"
drawText(
    hint,
    at: NSPoint(x: 0, y: 48),
    font: roundedFont(size: 10.5, weight: .medium),
    color: color(0xD5F7F2, alpha: 0.52),
    alignment: .center,
    width: logicalWidth
)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "dmg-background.png"
try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
print(outputPath)
