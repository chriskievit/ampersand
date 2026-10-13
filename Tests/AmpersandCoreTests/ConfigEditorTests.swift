import Foundation
import Testing
@testable import AmpersandCore

private func config() -> AppConfig {
    AppConfig(groups: [GroupSpec(id: "pro", name: "Storefront")], commands: [
        CommandSpec(name: "api", command: "kubectl port-forward svc/api 8080:80", group: "pro"),
        CommandSpec(name: "web", command: "npm run dev", group: "pro"),
        CommandSpec(name: "caffeinate", command: "caffeinate -dimsu", autoStart: true),
    ])
}

@Test func addAndUpdate() {
    var c = config()
    var spec = CommandSpec(name: "new", command: "true")
    ConfigEditor.add(spec, to: &c)
    #expect(c.commands.last == spec)
    spec.name = "renamed"
    ConfigEditor.update(spec, in: &c)
    #expect(c.commands.last?.name == "renamed")
}

@Test func deleteAndRestore() throws {
    var c = config()
    let web = c.commands[1]
    let deleted = try #require(ConfigEditor.delete(id: web.id, from: &c))
    #expect(deleted == DeletedCommand(spec: web, index: 1))
    #expect(!c.commands.contains(web))
    ConfigEditor.restore(deleted, in: &c)
    #expect(c.commands[1] == web)
}

@Test func duplicateInsertsAfterWithUniqueName() throws {
    var c = config()
    let caff = c.commands[2]
    let first = try #require(ConfigEditor.duplicate(id: caff.id, in: &c))
    let second = try #require(ConfigEditor.duplicate(id: caff.id, in: &c))
    #expect(first.name == "caffeinate copy")
    #expect(second.name == "caffeinate copy 2")
    #expect(first.id != caff.id && !first.autoStart && first.command == caff.command)
    #expect(c.commands[3].id == second.id && c.commands[4].id == first.id)
}

@Test func moveAndReorder() {
    var c = config()
    let caff = c.commands[2]
    ConfigEditor.move(id: caff.id, toGroup: "pro", in: &c)
    #expect(c.commands[2].group == "pro")
    ConfigEditor.reorder(id: caff.id, before: c.commands[0].id, in: &c)
    #expect(c.commands.map(\.name) == ["caffeinate", "api", "web"])
    ConfigEditor.reorder(id: caff.id, before: nil, in: &c)
    #expect(c.commands.map(\.name) == ["api", "web", "caffeinate"])
}

@Test func groupsLifecycle() {
    var c = config()
    let g1 = ConfigEditor.addGroup(named: "Storefront", to: &c)
    let g2 = ConfigEditor.addGroup(named: "  ", to: &c)
    #expect(g1.id == "storefront" && g1.name == "Storefront")
    #expect(g2.id == "group" && g2.name == "New Group")
    ConfigEditor.renameGroup(id: "pro", to: "Pro", in: &c)
    #expect(c.groups[0].name == "Pro")
    ConfigEditor.deleteGroup(id: "pro", in: &c)
    #expect(c.commands.allSatisfy { $0.group == nil })
    #expect(!c.groups.contains { $0.id == "pro" })
}

@Test func sectionsOrderGroupsThenUngrouped() {
    var c = config()
    c.commands.append(CommandSpec(name: "orphan", command: "true", group: "deleted-group"))
    ConfigEditor.addGroup(named: "Empty", to: &c)
    let sections = ConfigEditor.sections(of: c)
    #expect(sections.map(\.id) == ["pro", "empty", ""])
    #expect(sections[0].commands.map(\.name) == ["api", "web"])
    #expect(sections[1].commands.isEmpty)
    #expect(sections[2].commands.map(\.name) == ["caffeinate", "orphan"])
    #expect(ConfigEditor.sections(of: AppConfig(groups: [], commands: [])).isEmpty)
}
