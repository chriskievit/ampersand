import Foundation

public enum StartFailure: Sendable, Equatable {
    case folderMissing(String)
    case envFileUnreadable(String)
    case spawnFailed(String)
}

public enum CommandStatus: Sendable, Equatable {
    case stopped
    case starting(since: Date)
    case running(since: Date)
    case stopping
    case backoff(exit: ProcessExit, at: Date, restartAt: Date)
    case exited(ProcessExit, at: Date)
    /// Exited with status 0 on its own: not a crash, never restarted, never notified.
    case finished(at: Date)
    case gaveUp(exit: ProcessExit, at: Date)
    case failedToStart(StartFailure)

    public enum Kind: Sendable, Equatable {
        case stopped, starting, running, stopping, backoff, exited, finished, gaveUp, failed
    }

    public var kind: Kind {
        switch self {
        case .stopped: .stopped
        case .starting: .starting
        case .running: .running
        case .stopping: .stopping
        case .backoff: .backoff
        case .exited: .exited
        case .finished: .finished
        case .gaveUp: .gaveUp
        case .failedToStart: .failed
        }
    }

    /// True while Ampersand owns a live process or a pending restart.
    public var isActive: Bool {
        switch kind {
        case .starting, .running, .stopping, .backoff: true
        default: false
        }
    }
}

public enum SupervisorEvent: Sendable, Equatable {
    case status(CommandStatus)
    case output(newLines: [String], partialLine: String)
    case logCleared
}
