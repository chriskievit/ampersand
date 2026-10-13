import Foundation
import Testing
@testable import AmpersandCore

private func tempDir() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ampersand-tests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private let sample = AppConfig(
    version: 1,
    groups: [GroupSpec(id: "storefront", name: "Storefront")],
    commands: [
        CommandSpec(name: "web", command: "npm run dev", cwd: "~/dev/web",
                    env: "PORT=3000\n# local\n", group: "storefront", port: 3000,
                    health: .http(url: "http://localhost:3000/health")),
        CommandSpec(name: "caffeinate", command: "caffeinate -dimsu", autoStart: true, health: .tcp),
    ]
)

@Test func missingFileLoadsEmpty() throws {
    let store = ConfigStore(directory: tempDir())
    #expect(try store.load() == .empty)
}

@Test func roundTrip() throws {
    let store = ConfigStore(directory: tempDir())
    try store.save(sample)
    #expect(try store.load() == sample)
}

@Test func healthEncodingShape() throws {
    let store = ConfigStore(directory: tempDir())
    try store.save(sample)
    let text = try String(contentsOf: store.fileURL, encoding: .utf8)
    #expect(text.contains("\"type\" : \"http\""))
    #expect(text.contains("\"url\" : \"http:\\/\\/localhost:3000\\/health\"") || text.contains("\"url\" : \"http://localhost:3000/health\""))
    #expect(text.contains("\"type\" : \"tcp\""))
}

@Test func outputIsStableAcrossSaves() throws {
    let store = ConfigStore(directory: tempDir())
    try store.save(sample)
    let first = try Data(contentsOf: store.fileURL)
    try store.save(try store.load())
    #expect(try Data(contentsOf: store.fileURL) == first)
}

@Test func corruptFileIsPreserved() throws {
    let dir = tempDir()
    let store = ConfigStore(directory: dir)
    try "{ not json".write(to: store.fileURL, atomically: true, encoding: .utf8)
    #expect(throws: ConfigError.self) { try store.load() }
    #expect(try String(contentsOf: store.fileURL, encoding: .utf8) == "{ not json")
}

@Test func futureVersionRejected() throws {
    let store = ConfigStore(directory: tempDir())
    try #"{"version":2,"groups":[],"commands":[]}"#.write(to: store.fileURL, atomically: true, encoding: .utf8)
    #expect(throws: ConfigError.unsupportedVersion(2)) { try store.load() }
}

@Test func exportAndImport() throws {
    let store = ConfigStore(directory: tempDir())
    let target = tempDir().appendingPathComponent("backup.json")
    try store.export(sample, to: target)
    #expect(try store.importConfig(from: target) == sample)
}

@Test func tildeExpansion() {
    let spec = CommandSpec(name: "x", command: "true", cwd: "~/dev")
    #expect(spec.expandedCwd == NSHomeDirectory() + "/dev")
    #expect(CommandSpec(name: "x", command: "true").expandedCwd == nil)
}
