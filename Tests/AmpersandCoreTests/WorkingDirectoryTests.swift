import Foundation
import Testing
@testable import AmpersandCore

private func config() -> AppConfig {
    AppConfig(groups: [GroupSpec(id: "shop", name: "Shop", cwd: "~/dev/shop"), GroupSpec(id: "bare", name: "Bare")],
              commands: [
                CommandSpec(name: "api", command: "make api", group: "shop"),
                CommandSpec(name: "web", command: "npm run dev", cwd: "/srv/web", group: "shop"),
                CommandSpec(name: "tool", command: "true", group: "bare"),
                CommandSpec(name: "loose", command: "true"),
                CommandSpec(name: "blank", command: "true", cwd: "  ", group: "shop"),
              ])
}

@Test func pathValidation() {
    #expect(WorkingDirectory.problem("") == nil)
    #expect(WorkingDirectory.problem("   ") == nil)
    #expect(WorkingDirectory.problem("/srv/web") == nil)
    #expect(WorkingDirectory.problem("~") == nil)
    #expect(WorkingDirectory.problem("~/dev/x") == nil)
    #expect(WorkingDirectory.problem("web") != nil)
    #expect(WorkingDirectory.problem("./web") != nil)
}

@Test func effectiveFolderMostSpecificWins() {
    let c = config()
    let byName = Dictionary(uniqueKeysWithValues: c.commands.map { ($0.name, $0) })
    #expect(ConfigEditor.effectiveCwd(of: byName["api"]!, in: c) == "~/dev/shop")     // inherits
    #expect(ConfigEditor.effectiveCwd(of: byName["web"]!, in: c) == "/srv/web")       // its own wins
    #expect(ConfigEditor.effectiveCwd(of: byName["blank"]!, in: c) == "~/dev/shop")   // blank counts as unset
    #expect(ConfigEditor.effectiveCwd(of: byName["tool"]!, in: c) == nil)             // group without a folder
    #expect(ConfigEditor.effectiveCwd(of: byName["loose"]!, in: c) == nil)            // no group
    let launch = ConfigEditor.launchSpec(for: byName["api"]!, in: c)
    #expect(launch.cwd == "~/dev/shop" && launch.expandedCwd?.hasPrefix("/") == true)
    #expect(launch.group == "shop" && launch.id == byName["api"]!.id)
}

@Test func groupFolderEditsAndChanges() {
    var c = config()
    let before = c
    ConfigEditor.setGroupCwd(id: "shop", to: "  /opt/shop ", in: &c)
    #expect(c.groups[0].cwd == "/opt/shop")
    // web has its own folder, so only api and blank change.
    #expect(Set(ConfigEditor.cwdChanges(from: before, to: c)) == Set(before.commands.filter { ["api", "blank"].contains($0.name) }.map(\.id)))
    ConfigEditor.setGroupCwd(id: "shop", to: " ", in: &c)
    #expect(c.groups[0].cwd == nil)
    // Moving api to a group without a folder changes it too.
    var moved = before
    ConfigEditor.move(id: before.commands[0].id, toGroup: "bare", in: &moved)
    #expect(ConfigEditor.cwdChanges(from: before, to: moved) == [before.commands[0].id])
    #expect(ConfigEditor.cwdChanges(from: before, to: before).isEmpty)
}

@Test func groupFolderIsOptionalInJSON() throws {
    let old = #"{"version":1,"groups":[{"id":"g","name":"G"}],"commands":[]}"#
    let decoded = try JSONDecoder().decode(AppConfig.self, from: Data(old.utf8))
    #expect(decoded.groups == [GroupSpec(id: "g", name: "G")])
    let encoded = String(decoding: try JSONEncoder().encode(GroupSpec(id: "g", name: "G")), as: UTF8.self)
    #expect(!encoded.contains("cwd"))
    let roundTrip = try JSONDecoder().decode(GroupSpec.self, from: JSONEncoder().encode(GroupSpec(id: "g", name: "G", cwd: "~/x")))
    #expect(roundTrip.cwd == "~/x")
}

@Test func draftRejectsRelativeFolder() {
    var d = CommandDraft()
    d.commandText = "npm run dev"
    d.cwd = "web"
    #expect(d.validationMessage == "Working directory: \(WorkingDirectory.problem("web")!)")
    d.cwd = "~/web"
    #expect(d.isValid)
}

@Test func draftRejectsRelativeFolderFromCdPrefix() {
    var d = CommandDraft()
    d.commandText = "cd web && npm run dev"
    #expect(d.makeSpec().cwd == "web")
    #expect(!d.isValid)
    d.dismissedChips = [.cwd]   // keep the cd in the command line instead
    #expect(d.isValid)
}
