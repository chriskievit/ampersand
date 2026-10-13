import Darwin
import Foundation

public struct ResourceSample: Sendable, Equatable {
    public var cpuPercent: Double
    public var residentBytes: UInt64
    public init(cpuPercent: Double, residentBytes: UInt64) {
        self.cpuPercent = cpuPercent; self.residentBytes = residentBytes
    }
}

/// Turns cumulative CPU time per process group into a percentage between samples.
public struct ResourceSampler: Sendable {
    public typealias Reader = @Sendable (pid_t) -> ProcessTree.Usage
    public static let liveReader: Reader = { ProcessTree.usage(of: ProcessTree.pids(inGroup: $0)) }

    private struct Previous: Sendable { var time: Date; var cpu: UInt64 }
    private let reader: Reader
    private var previous: [pid_t: Previous] = [:]

    public init(reader: @escaping Reader = ResourceSampler.liveReader) { self.reader = reader }

    public mutating func sample(group: pid_t, at now: Date) -> ResourceSample {
        let usage = reader(group)
        defer { previous[group] = Previous(time: now, cpu: usage.cpuNanoseconds) }
        guard let last = previous[group], now > last.time, usage.cpuNanoseconds >= last.cpu else {
            return ResourceSample(cpuPercent: 0, residentBytes: usage.residentBytes)
        }
        let seconds = now.timeIntervalSince(last.time)
        let percent = Double(usage.cpuNanoseconds - last.cpu) / (seconds * 1_000_000_000) * 100
        return ResourceSample(cpuPercent: percent, residentBytes: usage.residentBytes)
    }

    public mutating func forget(group: pid_t) { previous[group] = nil }
}
