import AmpersandCore
import AppKit
import SwiftUI

/// Maps ANSI styles onto text attributes. Log colours are content, so they keep their hue,
/// mapped to system colours where one exists so they adapt to light and dark.
enum ANSIAttributes {
    static func attributes(for style: ANSIStyle) -> [NSAttributedString.Key: Any] {
        let size = NSFont.systemFontSize
        var font = NSFont.monospacedSystemFont(ofSize: size, weight: style.bold ? .bold : .regular)
        if style.italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
        var foreground = style.foreground.map(color) ?? .textColor
        if style.dim { foreground = foreground.withAlphaComponent(0.6) }
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
        if let background = style.background { attributes[.backgroundColor] = color(background) }
        if style.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        return attributes
    }

    private static func color(_ color: ANSIColor) -> NSColor {
        switch color {
        case .standard(let index): standard(index)
        case .palette(let index): palette(index)
        case .rgb(let r, let g, let b): NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        }
    }

    private static func standard(_ index: Int) -> NSColor {
        switch index % 8 {
        case 0: index < 8 ? .labelColor : .tertiaryLabelColor
        case 1: .systemRed
        case 2: .systemGreen
        case 3: .systemYellow
        case 4: .systemBlue
        case 5: .systemPurple
        case 6: .systemCyan
        default: index < 8 ? .secondaryLabelColor : .labelColor
        }
    }

    private static func palette(_ index: Int) -> NSColor {
        if index < 16 { return standard(index) }
        if index >= 232 {
            let level = CGFloat(8 + (index - 232) * 10) / 255
            return NSColor(srgbRed: level, green: level, blue: level, alpha: 1)
        }
        let cube = index - 16
        func component(_ value: Int) -> CGFloat { value == 0 ? 0 : CGFloat(55 + value * 40) / 255 }
        return NSColor(srgbRed: component(cube / 36), green: component((cube / 6) % 6), blue: component(cube % 6), alpha: 1)
    }
}

/// Read-only NSTextView that appends only new lines (fast with 10,000-line scrollback).
struct LogView: NSViewRepresentable {
    let runtime: CommandRuntime
    // Passed explicitly so SwiftUI re-runs updateNSView when they change.
    let totalCommitted: Int
    let partialLine: String
    let generation: Int
    @Binding var follow: Bool

    func makeCoordinator() -> Coordinator { Coordinator(follow: $follow) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticLinkDetectionEnabled = false
        scrollView.hasVerticalScroller = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        context.coordinator.attach(scrollView: scrollView, textView: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.follow = $follow
        context.coordinator.render(runtime: runtime, follow: follow)
    }

    @MainActor
    final class Coordinator: NSObject {
        var follow: Binding<Bool>
        private weak var textView: NSTextView?
        private weak var scrollView: NSScrollView?
        private var runtimeID: UUID?
        private var generation = -1
        private var renderedTotal = 0
        private var committedLinesInView = 0
        private var partialLength = 0
        private var parser = ANSIParser()
        private var isProgrammaticScroll = false

        init(follow: Binding<Bool>) { self.follow = follow }

        func attach(scrollView: NSScrollView, textView: NSTextView) {
            self.scrollView = scrollView
            self.textView = textView
            NotificationCenter.default.addObserver(self, selector: #selector(boundsChanged),
                                                   name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        }

        func render(runtime: CommandRuntime, follow: Bool) {
            guard let storage = textView?.textStorage else { return }
            let newCount = runtime.totalCommitted - renderedTotal
            let needsReset = runtime.id != runtimeID || runtime.logGeneration != generation
                || newCount < 0 || newCount > runtime.lines.count
            storage.beginEditing()
            if partialLength > 0 {
                storage.deleteCharacters(in: NSRange(location: storage.length - partialLength, length: partialLength))
                partialLength = 0
            }
            if needsReset {
                storage.setAttributedString(NSAttributedString())
                parser = ANSIParser()
                runtimeID = runtime.id
                generation = runtime.logGeneration
                committedLinesInView = 0
                append(runtime.lines, to: storage)
            } else if newCount > 0 {
                append(Array(runtime.lines.suffix(newCount)), to: storage)
            }
            renderedTotal = runtime.totalCommitted
            if !runtime.partialLine.isEmpty {
                var partialParser = parser   // the partial line must not advance the real parser
                let text = styled(runtime.partialLine, with: &partialParser)
                storage.append(text)
                partialLength = text.length
            }
            trimIfNeeded(storage)
            storage.endEditing()
            if follow { scrollToBottom() }
        }

        private func append(_ lines: [String], to storage: NSTextStorage) {
            let chunk = NSMutableAttributedString()
            for line in lines {
                chunk.append(styled(line, with: &parser))
                chunk.append(NSAttributedString(string: "\n", attributes: ANSIAttributes.attributes(for: .plain)))
            }
            storage.append(chunk)
            committedLinesInView += lines.count
        }

        private func styled(_ line: String, with parser: inout ANSIParser) -> NSAttributedString {
            let result = NSMutableAttributedString()
            for run in parser.parse(line) {
                result.append(NSAttributedString(string: run.text, attributes: ANSIAttributes.attributes(for: run.style)))
            }
            return result
        }

        /// Keeps the view near the 10,000-line cap; trims in chunks of 1,000 lines.
        private func trimIfNeeded(_ storage: NSTextStorage) {
            guard committedLinesInView > CommandRuntime.logCapacity + 1_000 else { return }
            let excess = committedLinesInView - CommandRuntime.logCapacity
            let string = storage.string as NSString
            var location = 0
            for _ in 0..<excess {
                let range = string.range(of: "\n", range: NSRange(location: location, length: string.length - location))
                guard range.location != NSNotFound else { break }
                location = range.location + 1
            }
            storage.deleteCharacters(in: NSRange(location: 0, length: location))
            committedLinesInView -= excess
        }

        private func scrollToBottom() {
            isProgrammaticScroll = true
            textView?.scrollToEndOfDocument(nil)
            isProgrammaticScroll = false
        }

        @objc private func boundsChanged(_ notification: Notification) {
            guard !isProgrammaticScroll, let scrollView, let document = scrollView.documentView else { return }
            let visible = scrollView.contentView.bounds
            let atBottom = visible.maxY >= document.bounds.maxY - 4
            if follow.wrappedValue != atBottom { follow.wrappedValue = atBottom }
        }
    }
}
