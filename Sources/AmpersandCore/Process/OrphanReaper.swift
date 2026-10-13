import Darwin
import Foundation

/// A process group Ampersand started, identified by its leader's start time.
/// The start time survives `exec` (zsh replaces itself with the last command) and
/// defeats pid reuse, unlike the leader's argv.
public struct TrackedProcess: Codable, Sendable, Equatable {
    public var pgid: Int32
    public var startTime: UInt64   // microseconds since the epoch
    public init(pgid: Int32, startTime: UInt64) { self.pgid = pgid; self.startTime = startTime }
}

/// Remembers the process groups Ampersand started so a crashed session can be cleaned up.
public final class OrphanReaper: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public func record(_ processes: [TrackedProcess]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(processes).write(to: fileURL, options: .atomic)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    @discardableResult
    public func reap() -> Int {
        defer { clear() }
        guard let data = try? Data(contentsOf: fileURL),
              let tracked = try? JSONDecoder().decode([TrackedProcess].self, from: data) else { return 0 }
        let matching = tracked.filter {
            processGroupIsAlive($0.pgid) && Self.startTime(of: $0.pgid) == $0.startTime
        }
        guard !matching.isEmpty else { return 0 }
        matching.forEach { _ = kill(-$0.pgid, SIGTERM) }
        usleep(500_000)
        matching.filter { processGroupIsAlive($0.pgid) }.forEach { _ = kill(-$0.pgid, SIGKILL) }
        return matching.count
    }

    /// The process's start time in microseconds since the epoch, or nil if it is gone.
    public static func startTime(of pid: pid_t) -> UInt64? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return UInt64(info.pbi_start_tvsec) * 1_000_000 + UInt64(info.pbi_start_tvusec)
    }
}
