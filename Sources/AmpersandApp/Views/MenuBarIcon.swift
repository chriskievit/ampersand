import AmpersandCore
import AppKit
import SwiftUI

/// Template image of an "&". Dimmed when idle; the active count beside it; a crash mark
/// (a disc with a cut-out "!", shape, not colour) when something needs attention.
enum MenuBarIcon {
    static let showCountKey = "showActiveCountInMenuBar"

    private static let height: CGFloat = 18
    private static let markDiameter: CGFloat = 9

    static func image(active: Bool, count: String?, attention: Bool) -> NSImage {
        let ampersand = NSAttributedString(string: "&", attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular) + 2, weight: .semibold),
            .foregroundColor: NSColor.black.withAlphaComponent(active ? 1 : 0.45),
        ])
        let number = count.map {
            NSAttributedString(string: $0, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .semibold),
                .foregroundColor: NSColor.black,
            ])
        }

        // Idle keeps the old 20 pt footprint; a count or the mark widens the image only then.
        let ampersandWidth = ampersand.size().width
        let numberWidth = number?.size().width ?? 0
        var width = 2 + ampersandWidth + 2
        if number != nil { width += 1 + numberWidth }
        if attention { width += 2 + markDiameter }
        width = max(20, ceil(width))

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            var x: CGFloat = (number == nil && !attention) ? (rect.width - ampersandWidth) / 2 : 2
            ampersand.draw(at: NSPoint(x: x, y: (rect.height - ampersand.size().height) / 2))
            x += ampersandWidth
            if let number {
                x += 1
                number.draw(at: NSPoint(x: x, y: (rect.height - number.size().height) / 2))
                x += numberWidth
            }
            if attention {
                x += 2
                drawCrashMark(in: NSRect(x: x, y: (rect.height - markDiameter) / 2,
                                         width: markDiameter, height: markDiameter))
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// A filled disc with an "!" knocked out of it, so it reads in any menu bar tint.
    private static func drawCrashMark(in rect: NSRect) {
        NSColor.black.setFill()
        NSBezierPath(ovalIn: rect).fill()
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        context.compositingOperation = .destinationOut
        let stemWidth: CGFloat = 1.6
        let midX = rect.midX - stemWidth / 2
        NSBezierPath(roundedRect: NSRect(x: midX, y: rect.minY + 3.6, width: stemWidth, height: 3.6),
                     xRadius: stemWidth / 2, yRadius: stemWidth / 2).fill()
        NSBezierPath(ovalIn: NSRect(x: midX, y: rect.minY + 1.4, width: stemWidth, height: stemWidth)).fill()
        context.restoreGraphicsState()
    }
}

struct MenuBarLabel: View {
    let model: AppModel
    @AppStorage(MenuBarIcon.showCountKey) private var showCount = true
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: MenuBarIcon.image(active: model.activeCount > 0,
                                         count: showCount ? StatusText.menuBarCount(model.activeCount) : nil,
                                         attention: model.attentionCount > 0))
            .accessibilityLabel(StatusText.menuBarLabel(active: model.activeCount, crashed: model.attentionCount))
            .onAppear {
                model.openMainWindow = {
                    openWindow(id: "main")
                    NSApp.activate()
                }
            }
    }
}
