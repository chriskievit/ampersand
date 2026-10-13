import Foundation

public struct ConfigSection: Sendable, Equatable, Identifiable {
    public var group: GroupSpec?
    public var commands: [CommandSpec]
    public var id: String { group?.id ?? "" }
}

public struct DeletedCommand: Sendable, Equatable {
    public var spec: CommandSpec
    public var index: Int
}

/// Every configuration edit the UI can make, as pure functions on AppConfig.
public enum ConfigEditor {
    public static func add(_ spec: CommandSpec, to config: inout AppConfig) {
        config.commands.append(spec)
    }

    public static func update(_ spec: CommandSpec, in config: inout AppConfig) {
        guard let i = config.commands.firstIndex(where: { $0.id == spec.id }) else { return }
        config.commands[i] = spec
    }

    @discardableResult
    public static func delete(id: UUID, from config: inout AppConfig) -> DeletedCommand? {
        guard let i = config.commands.firstIndex(where: { $0.id == id }) else { return nil }
        return DeletedCommand(spec: config.commands.remove(at: i), index: i)
    }

    public static func restore(_ deleted: DeletedCommand, in config: inout AppConfig) {
        config.commands.insert(deleted.spec, at: min(deleted.index, config.commands.count))
    }

    @discardableResult
    public static func duplicate(id: UUID, in config: inout AppConfig) -> CommandSpec? {
        guard let i = config.commands.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = config.commands[i]
        copy.id = UUID()
        copy.autoStart = false
        let names = Set(config.commands.map(\.name))
        var candidate = "\(copy.name) copy"
        var n = 2
        while names.contains(candidate) { candidate = "\(copy.name) copy \(n)"; n += 1 }
        copy.name = candidate
        config.commands.insert(copy, at: i + 1)
        return copy
    }

    public static func move(id: UUID, toGroup group: String?, in config: inout AppConfig) {
        guard let i = config.commands.firstIndex(where: { $0.id == id }) else { return }
        config.commands[i].group = group
    }

    public static func reorder(id: UUID, before target: UUID?, in config: inout AppConfig) {
        guard id != target, let i = config.commands.firstIndex(where: { $0.id == id }) else { return }
        let spec = config.commands.remove(at: i)
        if let target, let j = config.commands.firstIndex(where: { $0.id == target }) {
            config.commands.insert(spec, at: j)
        } else {
            config.commands.append(spec)
        }
    }

    @discardableResult
    public static func addGroup(named name: String, to config: inout AppConfig) -> GroupSpec {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let display = trimmed.isEmpty ? "New Group" : trimmed
        var base = trimmed.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
            .split(separator: "-").joined(separator: "-")
        if base.isEmpty { base = "group" }
        let existing = Set(config.groups.map(\.id))
        var id = base
        var n = 2
        while existing.contains(id) { id = "\(base)-\(n)"; n += 1 }
        let group = GroupSpec(id: id, name: display)
        config.groups.append(group)
        return group
    }

    public static func renameGroup(id: String, to name: String, in config: inout AppConfig) {
        guard let i = config.groups.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { config.groups[i].name = trimmed }
    }

    public static func deleteGroup(id: String, in config: inout AppConfig) {
        config.groups.removeAll { $0.id == id }
        for i in config.commands.indices where config.commands[i].group == id {
            config.commands[i].group = nil
        }
    }

    public static func sections(of config: AppConfig) -> [ConfigSection] {
        let known = Set(config.groups.map(\.id))
        var sections = config.groups.map { group in
            ConfigSection(group: group, commands: config.commands.filter { $0.group == group.id })
        }
        let ungrouped = config.commands.filter { $0.group.map { !known.contains($0) } ?? true }
        if !ungrouped.isEmpty { sections.append(ConfigSection(group: nil, commands: ungrouped)) }
        return sections
    }
}
