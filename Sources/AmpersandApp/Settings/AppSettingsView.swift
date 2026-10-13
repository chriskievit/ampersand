import AppKit
import SwiftUI
import UserNotifications

/// ⌘, Settings: three items (spec 4.4).
struct AppSettingsView: View {
    @AppStorage(NotificationService.enabledKey) private var notificationsEnabled = true
    @AppStorage(AppDefaults.restartOnCrashKey) private var restartDefault = true
    @State private var launchAtLogin = LoginItemService.isEnabled
    @State private var loginError: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        try LoginItemService.setEnabled(enabled)
                        loginError = nil
                    } catch {
                        loginError = "Couldn’t change the login item: \(error.localizedDescription)"
                        launchAtLogin = LoginItemService.isEnabled
                    }
                }
            if let loginError {
                Text(loginError).foregroundStyle(.secondary)
            }
            Toggle("Notify me when a command crashes", isOn: $notificationsEnabled)
            if notificationsEnabled && notificationStatus == .denied {
                HStack {
                    Text("Notifications are off for Ampersand in System Settings.")
                        .foregroundStyle(.secondary)
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            Toggle("Restart new commands when they crash", isOn: $restartDefault)
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .task { notificationStatus = await NotificationService.authorizationStatus() }
    }
}
