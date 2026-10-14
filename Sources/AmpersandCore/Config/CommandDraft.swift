import Foundation

public enum DraftChip: String, Sendable, Hashable, CaseIterable { case cwd, env, port, name, health }
public enum HealthChoice: String, Sendable, Hashable, CaseIterable { case none, port, url }

public struct DraftSuggestion: Sendable, Equatable, Identifiable {
    public var chip: DraftChip
    public var label: String
    public var id: DraftChip { chip }
}

/// Editable state of the add/edit form, with the spec 6.1 suggestion rules.
public struct CommandDraft: Sendable, Equatable {
    public var id: UUID
    public var commandText = ""
    public var name = ""
    public var group: String?
    public var cwd = ""
    public var envText = ""
    public var envFile = ""
    public var portText = ""
    public var health: HealthChoice = .none
    public var healthURL = ""
    public var autoStart = false
    public var restart: Bool
    public var dismissedChips: Set<DraftChip> = []

    /// The saved command line of an existing command; chips stay off until the text changes.
    private var baselineCommand: String?

    public init(restartDefault: Bool = true) {
        id = UUID()
        restart = restartDefault
    }

    public init(spec: CommandSpec) {
        id = spec.id
        commandText = spec.command
        name = spec.name
        group = spec.group
        cwd = spec.cwd ?? ""
        envText = spec.env
        envFile = spec.envFile ?? ""
        portText = spec.port.map(String.init) ?? ""
        switch spec.health {
        case nil: health = .none
        case .tcp: health = .port
        case .http(let url): health = .url; healthURL = url
        }
        autoStart = spec.autoStart
        restart = spec.restart
        baselineCommand = spec.command
    }

    // MARK: Suggestions

    private var parsed: CommandSuggestions? {
        guard commandText != baselineCommand else { return nil }
        return CommandLineParser.parse(commandText)
    }

    private static func blank(_ s: String) -> Bool { s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public var suggestions: [DraftSuggestion] {
        guard let p = parsed else { return [] }
        var out: [DraftSuggestion] = []
        if let cwd = p.cwd, Self.blank(self.cwd) { out.append(.init(chip: .cwd, label: "Folder \(cwd)")) }
        if !p.envLines.isEmpty { out.append(.init(chip: .env, label: "Env \(p.envLines.joined(separator: ", "))")) }
        if let port = p.port, Self.blank(portText) { out.append(.init(chip: .port, label: "Port \(port)")) }
        if let name = p.name, Self.blank(self.name) { out.append(.init(chip: .name, label: "Name \(name)")) }
        if p.health != nil, health == .none { out.append(.init(chip: .health, label: "TCP Health Check")) }
        return out.filter { !dismissedChips.contains($0.chip) }
    }

    private func accepted(_ chip: DraftChip) -> Bool { suggestions.contains { $0.chip == chip } }

    // MARK: Validation

    public var envErrors: [EnvParseError] { EnvParser.parse(envText).errors }

    public var validationMessage: String? {
        if Self.blank(commandText) { return "Enter a command." }
        let port = Int(portText.trimmingCharacters(in: .whitespaces))
        if !Self.blank(portText), !(1...65535).contains(port ?? 0) { return "Port must be a number from 1 to 65535." }
        if health == .port, makeSpec().port == nil { return "A port health check needs a port." }
        if health == .url {
            let url = URL(string: healthURL.trimmingCharacters(in: .whitespaces))
            if !["http", "https"].contains(url?.scheme ?? "") || url?.host == nil {
                return "Enter a URL that starts with http:// or https://."
            }
        }
        if let problem = WorkingDirectory.problem(makeSpec().cwd ?? "") { return "Working directory: \(problem)" }
        if let error = envErrors.first { return "Environment line \(error.line): \(error.message)" }
        return nil
    }

    public var isValid: Bool { validationMessage == nil }

    // MARK: Output

    public func makeSpec() -> CommandSpec {
        let typed = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = parsed
        let hasCwdPrefix = p?.cwd != nil
        let hasEnvPrefix = !(p?.envLines.isEmpty ?? true)
        let strip = (hasCwdPrefix || hasEnvPrefix)
            && (!hasCwdPrefix || accepted(.cwd))
            && (!hasEnvPrefix || accepted(.env))

        var command = typed
        var cwdValue = Self.blank(cwd) ? nil : cwd.trimmingCharacters(in: .whitespaces)
        var env = envText
        if strip, let p {
            command = p.command
            if let prefixCwd = p.cwd { cwdValue = prefixCwd }
            if hasEnvPrefix { env = ([p.envLines.joined(separator: "\n")] + (envText.isEmpty ? [] : [envText])).joined(separator: "\n") }
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalName = !trimmedName.isEmpty ? trimmedName
            : (accepted(.name) ? p?.name : nil)
            ?? CommandLineParser.tokenize(Substring(command)).first.map { ($0 as NSString).lastPathComponent }
            ?? "Command"

        let port = Int(portText.trimmingCharacters(in: .whitespaces)) ?? (accepted(.port) ? p?.port : nil)

        let healthCheck: HealthCheck?
        switch health {
        case .none: healthCheck = accepted(.health) ? p?.health : nil
        case .port: healthCheck = .tcp
        case .url: healthCheck = .http(url: healthURL.trimmingCharacters(in: .whitespaces))
        }

        return CommandSpec(id: id, name: finalName, command: command, cwd: cwdValue, env: env,
                           envFile: Self.blank(envFile) ? nil : envFile.trimmingCharacters(in: .whitespaces),
                           group: group, autoStart: autoStart, port: port, health: healthCheck, restart: restart)
    }
}
