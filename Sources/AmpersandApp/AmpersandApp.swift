import SwiftUI

@main
struct AmpersandApp: App {
    var body: some Scene {
        // There is no "ampersand" SF Symbol; Task 17 replaces this with a drawn template image.
        MenuBarExtra {
            Text("Ampersand")
                .padding()
        } label: {
            Text("&")
        }
        .menuBarExtraStyle(.window)
    }
}
