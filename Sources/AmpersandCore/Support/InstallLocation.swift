import Foundation

/// Where the app bundle runs from, as far as a login item cares. A login item
/// records the bundle path, so a temporary or unusual location breaks it.
public enum InstallLocation: Equatable, Sendable {
    /// `/Applications` or `~/Applications`.
    case applications
    /// A quarantined copy that macOS runs from a random App Translocation path.
    case translocated
    /// Anywhere else, such as a mounted DMG, Downloads or a build folder.
    case elsewhere

    public init(bundlePath: String, home: String = NSHomeDirectory()) {
        let path = (bundlePath as NSString).standardizingPath
        let home = (home as NSString).standardizingPath
        if path.contains("/AppTranslocation/") {
            self = .translocated
        } else if path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/") {
            self = .applications
        } else {
            self = .elsewhere
        }
    }
}
