import Darwin
import Foundation

public struct TrackedProcess: Codable, Sendable, Equatable {
    public var pgid: Int32
    public var commandLine: String
    public init(pgid: Int32, commandLine: String) { self.pgid = pgid; self.commandLine = commandLine }
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
            processGroupIsAlive($0.pgid) && Self.commandLine(of: $0.pgid) == $0.commandLine
        }
        guard !matching.isEmpty else { return 0 }
        matching.forEach { _ = kill(-$0.pgid, SIGTERM) }
        usleep(500_000)
        matching.filter { processGroupIsAlive($0.pgid) }.forEach { _ = kill(-$0.pgid, SIGKILL) }
        return matching.count
    }

    /// The process's argv joined by spaces, read with sysctl(KERN_PROCARGS2).
    public static func commandLine(of pid: pid_t) -> String? {
        var argmax: Int32 = 0
        var size = MemoryLayout<Int32>.size
        var argmaxMIB: [Int32] = [CTL_KERN, KERN_ARGMAX]
        guard sysctl(&argmaxMIB, 2, &argmax, &size, nil, 0) == 0, argmax > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: Int(argmax))
        size = buffer.count
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }

        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }   // executable path
        while index < size, buffer[index] == 0 { index += 1 }   // padding
        var arguments: [String] = []
        while arguments.count < argc, index < size {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments.isEmpty ? nil : arguments.joined(separator: " ")
    }
}
