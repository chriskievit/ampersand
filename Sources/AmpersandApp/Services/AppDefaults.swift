import Foundation

enum AppDefaults {
    static let restartOnCrashKey = "restartOnCrashDefault"

    /// Default for "Restart on crash" in new commands (spec 4.4).
    static var restartOnCrash: Bool {
        UserDefaults.standard.object(forKey: restartOnCrashKey) as? Bool ?? true
    }
}
