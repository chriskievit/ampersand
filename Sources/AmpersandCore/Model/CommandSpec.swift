import Foundation

public enum HealthCheck: Codable, Sendable, Hashable {
    case tcp
    case http(url: String)

    private enum CodingKeys: String, CodingKey { case type, url }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "tcp": self = .tcp
        case "http": self = .http(url: try c.decode(String.self, forKey: .url))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c,
                debugDescription: "Unknown health check type \(other)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .tcp: try c.encode("tcp", forKey: .type)
        case .http(let url):
            try c.encode("http", forKey: .type)
            try c.encode(url, forKey: .url)
        }
    }
}

public struct GroupSpec: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    /// Working directory for the group's commands that have none of their own. Optional in JSON.
    public var cwd: String?
    public init(id: String, name: String, cwd: String? = nil) { self.id = id; self.name = name; self.cwd = cwd }
}

public struct CommandSpec: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var command: String
    public var cwd: String?
    public var env: String
    public var envFile: String?
    public var group: String?
    public var autoStart: Bool
    public var port: Int?
    public var health: HealthCheck?
    public var restart: Bool

    public init(
        id: UUID = UUID(), name: String, command: String, cwd: String? = nil,
        env: String = "", envFile: String? = nil, group: String? = nil,
        autoStart: Bool = false, port: Int? = nil, health: HealthCheck? = nil,
        restart: Bool = true
    ) {
        self.id = id; self.name = name; self.command = command; self.cwd = cwd
        self.env = env; self.envFile = envFile; self.group = group
        self.autoStart = autoStart; self.port = port; self.health = health
        self.restart = restart
    }

    /// Working directory with a leading `~` expanded, or nil when unset or blank.
    /// Only the command's own folder: `ConfigEditor.launchSpec` fills in the group's.
    public var expandedCwd: String? { WorkingDirectory.expanded(cwd) }
}

public struct AppConfig: Codable, Sendable, Equatable {
    public static let currentVersion = 1
    public static let empty = AppConfig(version: currentVersion, groups: [], commands: [])

    public var version: Int
    public var groups: [GroupSpec]
    public var commands: [CommandSpec]

    public init(version: Int = AppConfig.currentVersion, groups: [GroupSpec], commands: [CommandSpec]) {
        self.version = version; self.groups = groups; self.commands = commands
    }
}
