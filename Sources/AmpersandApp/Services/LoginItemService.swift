import AmpersandCore
import Foundation
import ServiceManagement

@MainActor
enum LoginItemService {
    enum Status { case enabled, disabled, needsApproval }

    /// What the user last chose in Settings, kept apart from what macOS reports.
    private static let wantedKey = "launchAtLogin"

    static var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .needsApproval
        default: .disabled
        }
    }

    static var location: InstallLocation { InstallLocation(bundlePath: Bundle.main.bundlePath) }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        UserDefaults.standard.set(enabled, forKey: wantedKey)
    }

    /// Registers again when the user wants the login item but macOS has none
    /// for this copy, as after an update (each ad hoc build has a new
    /// signature) or a move. Turned off in System Settings is
    /// `requiresApproval`, so the user's choice there stands.
    static func refreshRegistration() {
        // Records the choice for items registered before it was stored.
        if SMAppService.mainApp.status == .enabled { UserDefaults.standard.set(true, forKey: wantedKey) }
        guard UserDefaults.standard.bool(forKey: wantedKey),
              SMAppService.mainApp.status == .notRegistered,
              location != .translocated else { return }
        try? SMAppService.mainApp.register()
    }
}
