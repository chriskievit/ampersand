import AmpersandCore
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A development copy with its own config must not take over the installed app's login item.
        if ConfigStore.overrideDirectory() == nil { LoginItemService.refreshRegistration() }
        model.launch()
    }

    /// Stops every running command before quitting (spec 5.4).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.needsGracefulQuit else {
            model.finishQuitting()
            return .terminateNow
        }
        Task {
            await model.stopAll()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
