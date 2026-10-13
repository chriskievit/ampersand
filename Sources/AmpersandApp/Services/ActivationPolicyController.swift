import AppKit

/// Agent app (no Dock icon) until the main window opens; back to agent when it closes (spec 4.3).
@MainActor
enum ActivationPolicyController {
    static func windowDidAppear() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    static func windowDidDisappear() {
        NSApp.setActivationPolicy(.accessory)
    }
}
