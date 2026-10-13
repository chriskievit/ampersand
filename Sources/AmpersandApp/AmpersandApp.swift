import SwiftUI

@main
struct AmpersandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            CommandBarView(model: appDelegate.model)
        } label: {
            MenuBarLabel(model: appDelegate.model)
        }
        .menuBarExtraStyle(.window)
        Window("Ampersand", id: "main") {
            MainWindow(model: appDelegate.model)
        }
        .defaultSize(width: 900, height: 600)
        .windowToolbarStyle(.unified)
    }
}
