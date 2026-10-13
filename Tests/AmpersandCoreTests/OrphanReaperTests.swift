import Darwin
import Foundation
import Testing
@testable import AmpersandCore

private func reaperFile() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("pgids-\(UUID().uuidString).json")
}

@Suite(.serialized) struct OrphanReaperTests {
    @Test func startTimeSurvivesExec() async throws {
        let r = try testLaunch("sleep 30")   // zsh execs sleep: the leader's argv changes, its start time does not
        let before = try #require(OrphanReaper.startTime(of: r.pid))
        try await Task.sleep(for: .milliseconds(300))
        #expect(OrphanReaper.startTime(of: r.pid) == before)
        await r.terminate(grace: .seconds(1))
    }

    @Test func reapsGroupWhoseLeaderExeced() async throws {
        let r = try testLaunch("sleep 30")
        let file = reaperFile()
        try OrphanReaper(fileURL: file).record([
            TrackedProcess(pgid: r.pid, startTime: try #require(OrphanReaper.startTime(of: r.pid)))
        ])
        try await Task.sleep(for: .milliseconds(300))   // the exec has happened by now
        #expect(OrphanReaper(fileURL: file).reap() == 1)
        #expect(await waitUntil { !processGroupIsAlive(r.pid) })
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func skipsMismatchedStartTime() async throws {
        let r = try testLaunch("sleep 30")
        let file = reaperFile()
        let real = try #require(OrphanReaper.startTime(of: r.pid))
        try OrphanReaper(fileURL: file).record([TrackedProcess(pgid: r.pid, startTime: real &- 1)])
        #expect(OrphanReaper(fileURL: file).reap() == 0)
        #expect(processGroupIsAlive(r.pid))
        await r.terminate(grace: .seconds(1))
    }

    @Test func missingFileReapsNothing() {
        #expect(OrphanReaper(fileURL: reaperFile()).reap() == 0)
    }

    @Test func oldFormatFileReapsNothing() throws {
        let file = reaperFile()
        try #"[{"pgid":1,"commandLine":"x"}]"#.write(to: file, atomically: true, encoding: .utf8)
        #expect(OrphanReaper(fileURL: file).reap() == 0)
    }
}
