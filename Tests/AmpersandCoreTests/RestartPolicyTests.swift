import Foundation
import Testing
@testable import AmpersandCore

@Test func backoffDoublesThenGivesUpAfterFiveFastCrashes() {
    var p = RestartPolicy()
    var t = Date(timeIntervalSince1970: 0)
    var decisions: [RestartDecision] = []
    for _ in 0..<5 {
        decisions.append(p.recordCrash(at: t, uptime: 0.5))
        t += 5
    }
    #expect(decisions == [.restart(after: .seconds(1)), .restart(after: .seconds(2)),
                          .restart(after: .seconds(4)), .restart(after: .seconds(8)), .giveUp])
}

@Test func slowCrashesKeepRestartingWithCappedDelay() {
    var p = RestartPolicy()
    var t = Date(timeIntervalSince1970: 0)
    var last: RestartDecision = .giveUp
    for _ in 0..<10 {
        last = p.recordCrash(at: t, uptime: 30)   // never stable, but only ~3 per 2 min
        t += 45
    }
    #expect(last == .restart(after: .seconds(60)))
}

@Test func stableUptimeResetsBackoff() {
    var p = RestartPolicy()
    let t = Date(timeIntervalSince1970: 0)
    _ = p.recordCrash(at: t, uptime: 1)
    _ = p.recordCrash(at: t + 3, uptime: 1)
    #expect(p.recordCrash(at: t + 100, uptime: 61) == .restart(after: .seconds(1)))
}

@Test func explicitResetClearsHistory() {
    var p = RestartPolicy()
    let t = Date(timeIntervalSince1970: 0)
    for i in 0..<4 { _ = p.recordCrash(at: t + Double(i), uptime: 0.1) }
    p.reset()
    #expect(p.recordCrash(at: t + 5, uptime: 0.1) == .restart(after: .seconds(1)))
}
