import AmpersandCore
import AppKit
import SwiftUI

/// Template image of an "&". Dimmed when idle; a dot (shape, not colour) when something needs attention.
enum MenuBarIcon {
    static func image(active: Bool, attention: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { rect in
            let font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular) + 2, weight: .semibold)
            let text = NSAttributedString(string: "&", attributes: [
                .font: font,
                .foregroundColor: NSColor.black.withAlphaComponent(active ? 1 : 0.45),
            ])
            let size = text.size()
            text.draw(at: NSPoint(x: (rect.width - size.width) / 2 - (attention ? 2 : 0),
                                  y: (rect.height - size.height) / 2))
            if attention {
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: rect.width - 6, y: rect.height - 7, width: 5, height: 5)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

struct MenuBarLabel: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: MenuBarIcon.image(active: model.activeCount > 0, attention: model.attentionCount > 0))
            .accessibilityLabel(accessibilityText)
            .onAppear {
                model.openMainWindow = {
                    openWindow(id: "main")
                    NSApp.activate()
                }
            }
    }

    private var accessibilityText: String {
        var parts = ["Ampersand", "\(model.runningCount) running"]
        if model.attentionCount > 0 { parts.append("\(model.attentionCount) crashed") }
        return parts.joined(separator: ", ")
    }
}
