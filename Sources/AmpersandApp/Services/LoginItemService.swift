import AmpersandCore
import Foundation
import ServiceManagement

@MainActor
enum LoginItemService {
    enum Status { case enabled, disabled, needsApproval }

    private static let registeredBuildKey = "loginItemRegisteredBuild"

    static var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .needsApproval
        default: .disabled
        }
    }

    static var location: InstallLocation { InstallLocation(bundlePath: Bundle.main.bundlePath) }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(currentBuild, forKey: registeredBuildKey)
        } else {
            try SMAppService.mainApp.unregister()
            UserDefaults.standard.removeObject(forKey: registeredBuildKey)
        }
    }

    /// Registers again after an update or a move. Each ad hoc build has a new
    /// signature, and the login item records the old one and the old path.
    static func refreshRegistration() {
        guard status == .enabled, location != .translocated,
              UserDefaults.standard.string(forKey: registeredBuildKey) != currentBuild else { return }
        try? setEnabled(true)
    }

    /// The bundle path plus the executable's modification time: it changes on
    /// every new build and every move.
    private static var currentBuild: String {
        let modified = (try? Bundle.main.executableURL?
            .resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
        return "\(Bundle.main.bundlePath)|\(modified?.timeIntervalSince1970 ?? 0)"
    }
}
