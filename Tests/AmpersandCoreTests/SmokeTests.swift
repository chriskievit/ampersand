import Testing
@testable import AmpersandCore

@Test func systemClockAdvances() async throws {
    let clock = SystemClock()
    let start = clock.now
    try await clock.sleep(for: .milliseconds(20))
    #expect(clock.now.timeIntervalSince(start) >= 0.015)
}
