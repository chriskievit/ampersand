import Foundation

public enum ConfigError: Error, Equatable {
    case unreadable(String)
    case unsupportedVersion(Int)
}

/// Reads and writes config.json. Never overwrites a file it could not read:
/// callers must not call `save` after a failed `load` unless the user chose to.
public final class ConfigStore: Sendable {
    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("config.json") }

    public init(directory: URL) { self.directory = directory }

    public static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ampersand", isDirectory: true)
    }

    public func load() throws -> AppConfig {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        return try decode(Data(contentsOf: fileURL))
    }

    public func save(_ config: AppConfig) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encode(config).write(to: fileURL, options: .atomic)
    }

    public func export(_ config: AppConfig, to url: URL) throws {
        try encode(config).write(to: url, options: .atomic)
    }

    public func importConfig(from url: URL) throws -> AppConfig {
        try decode(Data(contentsOf: url))
    }

    private func encode(_ config: AppConfig) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(config)
    }

    private struct VersionProbe: Decodable { let version: Int }

    private func decode(_ data: Data) throws -> AppConfig {
        let decoder = JSONDecoder()
        let version: Int
        do { version = try decoder.decode(VersionProbe.self, from: data).version }
        catch { throw ConfigError.unreadable(String(describing: error)) }
        guard version <= AppConfig.currentVersion else { throw ConfigError.unsupportedVersion(version) }
        do { return try decoder.decode(AppConfig.self, from: data) }
        catch { throw ConfigError.unreadable(String(describing: error)) }
    }
}
