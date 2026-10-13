// Renders the DMG window background: a chevron between the app and the
// Applications shortcut, plus a one-line hint. Writes 1x and 2x PNGs.
// Usage: swift scripts/dmg-background.swift <output-dir>
// Positions must match scripts/dmg-settings.py (window 660x400, icons at y=180).
import AppKit

let size = CGSize(width: 660, height: 400)
let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/dmg")

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    NSColor(srgbRed: 0.945, green: 0.945, blue: 0.957, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()

    // Chevron centred between the two icons. AppKit's origin is bottom-left; Finder's is top-left.
    let mid = CGPoint(x: size.width / 2, y: size.height - 180)
    let chevron = NSBezierPath()
    chevron.move(to: CGPoint(x: mid.x - 9, y: mid.y + 18))
    chevron.line(to: CGPoint(x: mid.x + 9, y: mid.y))
    chevron.line(to: CGPoint(x: mid.x - 9, y: mid.y - 18))
    chevron.lineWidth = 5
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    NSColor(white: 0.2, alpha: 1).setStroke()
    chevron.stroke()

    let hint = "Drag Ampersand to Applications" as NSString
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    hint.draw(
        in: NSRect(x: 0, y: 70, width: size.width, height: 20),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(white: 0.45, alpha: 1),
            .paragraphStyle: paragraph,
        ])

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try render(scale: 1).write(to: outDir.appendingPathComponent("background.png"))
try render(scale: 2).write(to: outDir.appendingPathComponent("background@2x.png"))
print(outDir.path)
