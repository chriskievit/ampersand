import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

/// ⌘, Settings (spec 4.4).
struct AppSettingsView: View {
    @AppStorage(NotificationService.enabledKey) private var notificationsEnabled = true
    @AppStorage(AppDefaults.restartOnCrashKey) private var restartDefault = true
    @AppStorage(MenuBarIcon.showCountKey) private var showMenuBarCount = true
    @State private var loginStatus = LoginItemService.status
    @State private var loginError: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { loginStatus == .enabled },
                set: { setLaunchAtLogin($0) }))
            if loginStatus == .needsApproval {
                HStack {
                    Text("Ampersand is turned off in Login Items in System Settings.")
                        .foregroundStyle(.secondary)
                    Button("Open System Settings") { SMAppService.openSystemSettingsLoginItems() }
                }
            }
            if let locationNote {
                Text(locationNote).foregroundStyle(.secondary)
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
            Toggle("Show active count in menu bar", isOn: $showMenuBarCount)
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .task { notificationStatus = await NotificationService.authorizationStatus() }
        .onAppear { loginStatus = LoginItemService.status }
        // The user may have changed the login item in System Settings meanwhile.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginStatus = LoginItemService.status
        }
    }

    private var locationNote: String? {
        switch LoginItemService.location {
        case .applications: nil
        case .translocated:
            "macOS runs Ampersand from a temporary copy, so it can’t open at login. Move it to the Applications folder and open it from there."
        case .elsewhere:
            "Ampersand opens at login from where it is now. Keep it in the Applications folder so that moving it doesn’t break this."
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
            loginError = nil
        } catch {
            loginError = "Couldn’t change the login item: \(error.localizedDescription)"
        }
        loginStatus = LoginItemService.status
    }
}
