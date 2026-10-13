import Foundation

/// Injectable time source so timing logic (backoff, uptime) is testable.
public protocol Clock: Sendable {
    var now: Date { get }
    func sleep(for duration: Duration) async throws
}

public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
