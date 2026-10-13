import Darwin
import Foundation
import Synchronization
import Testing
@testable import AmpersandCore

@Test func samplerComputesPercentFromDeltas() {
    let readings = Mutex([ProcessTree.Usage(cpuNanoseconds: 0, residentBytes: 100),
                          ProcessTree.Usage(cpuNanoseconds: 1_000_000_000, residentBytes: 200),
                          ProcessTree.Usage(cpuNanoseconds: 500_000_000, residentBytes: 150)])
    var sampler = ResourceSampler(reader: { _ in readings.withLock { $0.removeFirst() } })
    let t0 = Date(timeIntervalSince1970: 0)
    #expect(sampler.sample(group: 1, at: t0) == ResourceSample(cpuPercent: 0, residentBytes: 100))
    #expect(sampler.sample(group: 1, at: t0 + 2) == ResourceSample(cpuPercent: 50, residentBytes: 200))
    // CPU total went down (a child exited): report 0, never negative
    #expect(sampler.sample(group: 1, at: t0 + 4) == ResourceSample(cpuPercent: 0, residentBytes: 150))
}

@Suite(.serialized) struct ProcessTreeLiveTests {
    @Test func groupListsBackgroundChildren() async throws {
        let r = try testLaunch("sleep 30 & sleep 30 & wait")
        #expect(await waitUntil { ProcessTree.pids(inGroup: r.pid).count >= 3 })
        #expect(ProcessTree.pids(inGroup: r.pid).contains(r.pid))
        await r.terminate(grace: .seconds(1))
    }

    @Test func busyLoopShowsCPUAndMemory() async throws {
        let r = try testLaunch("while :; do :; done")
        var sampler = ResourceSampler()
        _ = sampler.sample(group: r.pid, at: Date())
        try await Task.sleep(for: .seconds(1))
        let sample = sampler.sample(group: r.pid, at: Date())
        #expect(sample.cpuPercent > 30)
        #expect(sample.cpuPercent < 400)
        #expect(sample.residentBytes > 0)
        await r.terminate(grace: .seconds(1))
    }

    @Test func emptyGroupHasNoPids() {
        #expect(ProcessTree.pids(inGroup: 999_999).isEmpty)
    }
}
