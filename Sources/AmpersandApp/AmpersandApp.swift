import SwiftUI

@main
struct AmpersandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Placeholder content until Task 17 builds the popover.
        MenuBarExtra {
            VStack(alignment: .leading) {
                Text("\(appDelegate.model.runningCount) running")
                Button("Quit") { NSApp.terminate(nil) }
            }
            .padding()
        } label: {
            Text("&")
        }
        .menuBarExtraStyle(.window)
    }
}
