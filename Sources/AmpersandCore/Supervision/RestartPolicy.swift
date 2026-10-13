import Foundation

public enum RestartDecision: Sendable, Equatable {
    case restart(after: Duration)
    case giveUp
}

/// Pure backoff bookkeeping for one command (spec section 7).
public struct RestartPolicy: Sendable {
    public static let delays: [Duration] = [1, 2, 4, 8, 16, 32, 60].map { .seconds($0) }
    public static let maxCrashes = 5
    public static let window: TimeInterval = 120
    public static let stableUptime: TimeInterval = 60

    private var consecutive = 0
    private var crashTimes: [Date] = []

    public init() {}

    public mutating func recordCrash(at time: Date, uptime: TimeInterval) -> RestartDecision {
        if uptime >= Self.stableUptime { reset() }
        consecutive += 1
        crashTimes.append(time)
        crashTimes.removeAll { time.timeIntervalSince($0) > Self.window }
        if crashTimes.count >= Self.maxCrashes { return .giveUp }
        return .restart(after: Self.delays[min(consecutive - 1, Self.delays.count - 1)])
    }

    public mutating func reset() {
        consecutive = 0
        crashTimes.removeAll()
    }
}
