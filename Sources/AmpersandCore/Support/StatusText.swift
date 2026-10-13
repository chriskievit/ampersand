import Foundation

/// The words Ampersand shows for states and metrics. Kept here so the copy is tested.
public enum StatusText {
    public static let shortTime: @Sendable (Date) -> String = { $0.formatted(date: .omitted, time: .shortened) }

    public static func exitLabel(_ exit: ProcessExit) -> String {
        switch exit {
        case .exited(let code): "exit \(code)"
        case .signaled(let signal): "signal \(signal)"
        }
    }

    public static func stamp(for status: CommandStatus, now: Date, time: (Date) -> String = shortTime) -> String? {
        switch status {
        case .backoff(let exit, let at, let restartAt):
            let remaining = Int(restartAt.timeIntervalSince(now).rounded(.up))
            let tail = remaining > 0 ? "retry in \(remaining)s" : "restarting…"
            return "\(exitLabel(exit)) · \(time(at)) · \(tail)"
        case .exited(let exit, let at):
            return "\(exitLabel(exit)) · \(time(at))"
        case .finished(let at):
            return "exit 0 · \(time(at))"
        case .gaveUp(let exit, _):
            return "gave up after \(RestartPolicy.maxCrashes) restarts · \(exitLabel(exit))"
        case .failedToStart(let failure):
            return self.failure(failure)
        case .stopped, .starting, .running, .stopping:
            return nil
        }
    }

    public static func failure(_ failure: StartFailure) -> String {
        switch failure {
        case .folderMissing: "folder missing"
        case .envFileUnreadable: "can’t read env file"
        case .spawnFailed: "couldn’t start"
        }
    }

    public static func uptime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86_400 { return "\(s / 3600)h" + String(format: "%02d", (s % 3600) / 60) }
        return "\(s / 86_400)d \((s % 86_400) / 3600)h"
    }

    public static func memory(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        if mb < 1 { return String(format: "%.1f MB", mb) }
        return "\(Int(mb.rounded())) MB"
    }

    public static func cpu(_ percent: Double) -> String {
        percent < 10 ? String(format: "%.1f%%", percent) : "\(Int(percent.rounded()))%"
    }

    public static func stateWord(_ kind: CommandStatus.Kind) -> String {
        switch kind {
        case .stopped: "stopped"
        case .starting: "starting"
        case .running: "running"
        case .stopping: "stopping"
        case .backoff: "restarting"
        case .exited, .gaveUp: "crashed"
        case .finished: "finished"
        case .failed: "couldn’t start"
        }
    }
}
