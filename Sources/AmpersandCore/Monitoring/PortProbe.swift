import Darwin
import Foundation

public struct PortOwner: Sendable, Equatable {
    public var pid: pid_t
    public var name: String
    public init(pid: pid_t, name: String) { self.pid = pid; self.name = name }
}

/// Finds the process listening on a TCP port, via lsof.
public enum PortProbe {
    public static func owner(of port: Int) async -> PortOwner? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-Fpc"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        let output: String? = await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(decoding: data, as: UTF8.self))
            }
            do { try process.run() } catch { continuation.resume(returning: nil) }
        }
        return output.flatMap(parse)
    }

    /// Parses `lsof -F pc` output: `p<pid>` then `c<command>` lines.
    public static func parse(_ output: String) -> PortOwner? {
        var pid: pid_t?
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") { pid = pid_t(line.dropFirst()) }
            if line.hasPrefix("c"), let pid { return PortOwner(pid: pid, name: String(line.dropFirst())) }
        }
        return nil
    }
}
