import Darwin
import Foundation
import Testing
@testable import AmpersandCore

private func reaperFile() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("pgids-\(UUID().uuidString).json")
}

@Suite(.serialized) struct OrphanReaperTests {
    @Test func commandLineOfOwnChild() async throws {
        let r = try testLaunch("sleep 30; true")   // `; true` keeps zsh as the group leader
        try await Task.sleep(for: .milliseconds(100))
        let line = try #require(OrphanReaper.commandLine(of: r.pid))
        #expect(line.contains("sleep 30; true"))
        await r.terminate(grace: .seconds(1))
    }

    @Test func reapsMatchingGroup() async throws {
        let r = try testLaunch("sleep 30; true")
        try await Task.sleep(for: .milliseconds(100))
        let file = reaperFile()
        try OrphanReaper(fileURL: file).record([
            TrackedProcess(pgid: r.pid, commandLine: try #require(OrphanReaper.commandLine(of: r.pid)))
        ])
        #expect(OrphanReaper(fileURL: file).reap() == 1)
        #expect(await waitUntil { !processGroupIsAlive(r.pid) })
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func skipsMismatchedCommandLine() async throws {
        let r = try testLaunch("sleep 30; true")
        try await Task.sleep(for: .milliseconds(100))
        let file = reaperFile()
        try OrphanReaper(fileURL: file).record([TrackedProcess(pgid: r.pid, commandLine: "something else")])
        #expect(OrphanReaper(fileURL: file).reap() == 0)
        #expect(processGroupIsAlive(r.pid))
        await r.terminate(grace: .seconds(1))
    }

    @Test func missingFileReapsNothing() {
        #expect(OrphanReaper(fileURL: reaperFile()).reap() == 0)
    }
}
