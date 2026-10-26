import AppKit
import Foundation

let pixelSize = 1024
let canvas = CGFloat(pixelSize)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
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

let bodyRect = NSRect(x: 106, y: 106, width: 812, height: 812)
let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 188, yRadius: 188)

NSGraphicsContext.saveGraphicsState()
let bodyShadow = NSShadow()
bodyShadow.shadowColor = color(0x03343D, alpha: 0.42)
bodyShadow.shadowBlurRadius = 46
bodyShadow.shadowOffset = NSSize(width: 0, height: -18)
bodyShadow.set()
color(0x075E6B).setFill()
bodyPath.fill()
NSGraphicsContext.restoreGraphicsState()

let bodyGradient = NSGradient(colors: [
    color(0x18C7B4),
    color(0x0B9D9A),
    color(0x076173)
])!
bodyGradient.draw(in: bodyPath, angle: -58)

NSGraphicsContext.saveGraphicsState()
bodyPath.addClip()

let topGloss = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.24),
    NSColor.white.withAlphaComponent(0.04),
    NSColor.clear
])!
topGloss.draw(in: bodyRect, angle: -90)

let sheen = NSBezierPath()
sheen.move(to: NSPoint(x: 80, y: 560))
sheen.line(to: NSPoint(x: 700, y: 930))
sheen.line(to: NSPoint(x: 760, y: 930))
sheen.line(to: NSPoint(x: 200, y: 500))
sheen.close()
color(0xFFFFFF, alpha: 0.075).setFill()
sheen.fill()

let bottomShade = NSGradient(colors: [
    NSColor.clear,
    color(0x03343D, alpha: 0.20)
])!
bottomShade.draw(in: bodyRect, angle: 90)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
bodyPath.addClip()
let innerStroke = NSBezierPath(roundedRect: bodyRect.insetBy(dx: 4, dy: 4), xRadius: 184, yRadius: 184)
color(0xFFFFFF, alpha: 0.24).setStroke()
innerStroke.lineWidth = 3
innerStroke.stroke()
NSGraphicsContext.restoreGraphicsState()

let boardRect = NSRect(x: 296, y: 238, width: 432, height: 546)
let boardPath = NSBezierPath(roundedRect: boardRect, xRadius: 56, yRadius: 56)

NSGraphicsContext.saveGraphicsState()
let boardShadow = NSShadow()
boardShadow.shadowColor = color(0x022E37, alpha: 0.34)
boardShadow.shadowBlurRadius = 30
boardShadow.shadowOffset = NSSize(width: 0, height: -14)
boardShadow.set()
NSColor.white.setFill()
boardPath.fill()
NSGraphicsContext.restoreGraphicsState()

let boardGradient = NSGradient(colors: [
    color(0xFFFFFF),
    color(0xF2FCFA),
    color(0xDFF3F0)
])!
boardGradient.draw(in: boardPath, angle: -80)

NSGraphicsContext.saveGraphicsState()
boardPath.addClip()
let boardSheen = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.18),
    NSColor.clear
])!
boardSheen.draw(in: boardRect, angle: -90)
NSGraphicsContext.restoreGraphicsState()

color(0xC4E6E2, alpha: 0.8).setStroke()
boardPath.lineWidth = 2.5
boardPath.stroke()

let lineSpecs: [(y: CGFloat, width: CGFloat, color: NSColor)] = [
    (608, 282, color(0x0D9488)),
    (538, 232, color(0x8BA9AD)),
    (468, 258, color(0x9BB8BC)),
    (398, 176, color(0xBDD0D2))
]

for spec in lineSpecs {
    let lineRect = NSRect(x: 358, y: spec.y, width: spec.width, height: 24)
    let line = NSBezierPath(roundedRect: lineRect, xRadius: 12, yRadius: 12)
    spec.color.setFill()
    line.fill()
}

let clipRect = NSRect(x: 392, y: 742, width: 240, height: 94)
let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: 34, yRadius: 34)

NSGraphicsContext.saveGraphicsState()
let clipShadow = NSShadow()
clipShadow.shadowColor = color(0x8A3A08, alpha: 0.34)
clipShadow.shadowBlurRadius = 18
clipShadow.shadowOffset = NSSize(width: 0, height: -8)
clipShadow.set()
color(0xF47B20).setFill()
clipPath.fill()
NSGraphicsContext.restoreGraphicsState()

let clipGradient = NSGradient(colors: [
    color(0xFFD27A),
    color(0xFFB24A),
    color(0xF47B20)
])!
clipGradient.draw(in: clipPath, angle: -70)

NSGraphicsContext.saveGraphicsState()
clipPath.addClip()
let clipGloss = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.36),
    NSColor.clear
])!
clipGloss.draw(in: clipRect, angle: -90)
NSGraphicsContext.restoreGraphicsState()

let slotRect = NSRect(x: 462, y: 774, width: 100, height: 24)
let slot = NSBezierPath(roundedRect: slotRect, xRadius: 12, yRadius: 12)
color(0xC25A12, alpha: 0.52).setFill()
slot.fill()

color(0xFFFFFF, alpha: 0.30).setStroke()
slot.lineWidth = 1.2
slot.stroke()

func starPath(center: NSPoint, outer: CGFloat, inner: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: center.y + outer))
    path.curve(
        to: NSPoint(x: center.x + outer, y: center.y),
        controlPoint1: NSPoint(x: center.x + inner, y: center.y + inner),
        controlPoint2: NSPoint(x: center.x + inner, y: center.y + inner)
    )
    path.curve(
        to: NSPoint(x: center.x, y: center.y - outer),
        controlPoint1: NSPoint(x: center.x + inner, y: center.y - inner),
        controlPoint2: NSPoint(x: center.x + inner, y: center.y - inner)
    )
    path.curve(
        to: NSPoint(x: center.x - outer, y: center.y),
        controlPoint1: NSPoint(x: center.x - inner, y: center.y - inner),
        controlPoint2: NSPoint(x: center.x - inner, y: center.y - inner)
    )
    path.curve(
        to: NSPoint(x: center.x, y: center.y + outer),
        controlPoint1: NSPoint(x: center.x - inner, y: center.y + inner),
        controlPoint2: NSPoint(x: center.x - inner, y: center.y + inner)
    )
    path.close()
    return path
}

func drawStar(center: NSPoint, outer: CGFloat) {
    let path = starPath(center: center, outer: outer, inner: outer * 0.18)

    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = color(0xFFB24A, alpha: 0.65)
    glow.shadowBlurRadius = outer * 0.55
    glow.shadowOffset = .zero
    glow.set()
    let gradient = NSGradient(colors: [
        color(0xFFF3B0),
        color(0xFFC34D),
        color(0xF47B20)
    ])!
    gradient.draw(in: path, angle: -55)
    NSGraphicsContext.restoreGraphicsState()

    color(0xFFFFFF, alpha: 0.45).setStroke()
    path.lineWidth = max(1.5, outer * 0.035)
    path.stroke()
}

drawStar(center: NSPoint(x: 748, y: 714), outer: 68)
drawStar(center: NSPoint(x: 676, y: 810), outer: 20)
drawStar(center: NSPoint(x: 806, y: 790), outer: 11)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"
try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
print(outputPath)
