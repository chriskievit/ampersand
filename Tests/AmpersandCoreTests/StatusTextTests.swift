import Foundation
import Testing
@testable import AmpersandCore

private let t0 = Date(timeIntervalSince1970: 1_000)
private let fixedTime: @Sendable (Date) -> String = { _ in "14:02" }

@Test func exitLabels() {
    #expect(StatusText.exitLabel(.exited(1)) == "exit 1")
    #expect(StatusText.exitLabel(.signaled(9)) == "signal 9")
}

@Test func stamps() {
    #expect(StatusText.stamp(for: .backoff(exit: .exited(1), at: t0, restartAt: t0 + 4), now: t0 + 0.2, time: fixedTime)
            == "exit 1 · 14:02 · retry in 4s")
    #expect(StatusText.stamp(for: .backoff(exit: .exited(1), at: t0, restartAt: t0 + 4), now: t0 + 5, time: fixedTime)
            == "exit 1 · 14:02 · restarting…")
    #expect(StatusText.stamp(for: .exited(.signaled(9), at: t0), now: t0, time: fixedTime) == "signal 9 · 14:02")
    #expect(StatusText.stamp(for: .gaveUp(exit: .exited(1), at: t0), now: t0, time: fixedTime)
            == "gave up after 5 restarts · exit 1")
    #expect(StatusText.stamp(for: .failedToStart(.folderMissing("/x")), now: t0) == "folder missing")
    #expect(StatusText.stamp(for: .running(since: t0), now: t0) == nil)
    #expect(StatusText.stamp(for: .stopped, now: t0) == nil)
}

@Test func failures() {
    #expect(StatusText.failure(.envFileUnreadable("/a")) == "can’t read env file")
    #expect(StatusText.failure(.spawnFailed("x")) == "couldn’t start")
}

@Test func uptimes() {
    #expect(StatusText.uptime(12) == "12s")
    #expect(StatusText.uptime(41 * 60 + 5) == "41m")
    #expect(StatusText.uptime(2 * 3600 + 14 * 60) == "2h14")
    #expect(StatusText.uptime(2 * 3600 + 4 * 60) == "2h04")
    #expect(StatusText.uptime(3 * 86_400 + 4 * 3600) == "3d 4h")
}

@Test func memoryAndCPU() {
    #expect(StatusText.memory(84 * 1_048_576) == "84 MB")
    #expect(StatusText.memory(1_288_490_189) == "1.2 GB")
    #expect(StatusText.memory(300 * 1024) == "0.3 MB")
    #expect(StatusText.cpu(0.42) == "0.4%")
    #expect(StatusText.cpu(12.6) == "13%")
}

@Test func stateWords() {
    #expect(StatusText.stateWord(.running) == "running")
    #expect(StatusText.stateWord(.backoff) == "restarting")
    #expect(StatusText.stateWord(.gaveUp) == "crashed")
}

@Test func finishedStampAndWord() {
    #expect(StatusText.stamp(for: .finished(at: t0), now: t0, time: fixedTime) == "exit 0 · 14:02")
    #expect(StatusText.stateWord(.finished) == "finished")
}

@Test func rowMetricsShowOnlyWhatIsNotable() {
    let gib: UInt64 = 1_073_741_824
    #expect(StatusText.notableMetrics(ResourceSample(cpuPercent: 0.3, residentBytes: 84 * 1_048_576)).isEmpty)
    #expect(StatusText.notableMetrics(ResourceSample(cpuPercent: 49.9, residentBytes: gib - 1)).isEmpty)
    #expect(StatusText.notableMetrics(ResourceSample(cpuPercent: 50, residentBytes: 10)) == ["50%"])
    #expect(StatusText.notableMetrics(ResourceSample(cpuPercent: 1, residentBytes: gib)) == ["1.0 GB"])
    #expect(StatusText.notableMetrics(ResourceSample(cpuPercent: 120, residentBytes: 2 * gib)) == ["120%", "2.0 GB"])
}
