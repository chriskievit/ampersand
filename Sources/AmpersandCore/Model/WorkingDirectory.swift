import Foundation

/// Rules for a working directory, on a command or on a group: a full path or one that starts
/// with `~`. A relative path is rejected, so a command's folder never depends on its group's.
public enum WorkingDirectory {
    /// Why `path` can't be used, or nil when it is fine. Blank is fine: it means "not set".
    public static func problem(_ path: String) -> String? {
        guard let value = normalized(path) else { return nil }
        return value.hasPrefix("/") || value.hasPrefix("~") ? nil : "Use a full path that starts with / or ~."
    }

    /// Trimmed, or nil when blank.
    public static func normalized(_ path: String?) -> String? {
        guard let trimmed = path?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// With a leading `~` expanded, or nil when blank.
    public static func expanded(_ path: String?) -> String? {
        normalized(path).map { ($0 as NSString).expandingTildeInPath }
    }
}
