import Darwin
import Foundation
import Synchronization

public enum ProcessExit: Sendable, Equatable {
    case exited(Int32)
    case signaled(Int32)

    public init(waitStatus status: Int32) {
        let signal = status & 0x7F
        self = signal == 0 ? .exited((status >> 8) & 0xFF) : .signaled(signal)
    }
}

public protocol RunningProcess: AnyObject, Sendable {
    var pid: pid_t { get }
    var output: AsyncStream<[UInt8]> { get }
    var exitStatus: ProcessExit? { get }
    /// The consumer reports bytes it has processed, so the producer can apply backpressure.
    func consumed(_ byteCount: Int)
    func waitForExit() async -> ProcessExit
    @discardableResult func terminate(grace: Duration) async -> ProcessExit
}

public protocol ProcessLaunching: Sendable {
    func launch(_ configuration: LaunchConfiguration) throws -> any RunningProcess
}

public struct PTYProcessLauncher: ProcessLaunching {
    public init() {}
    public func launch(_ configuration: LaunchConfiguration) throws -> any RunningProcess {
        try ProcessRunner.launch(configuration)
    }
}

/// True while any process still belongs to the group.
public func processGroupIsAlive(_ pgid: pid_t) -> Bool {
    kill(-pgid, 0) == 0 || errno == EPERM
}

/// One child process on a pty. Output arrives on `output` until every holder of the
/// pty closes it; exit is observed with a kqueue process source plus a WNOHANG reap.
public final class ProcessRunner: RunningProcess {
    public let pid: pid_t
    public let output: AsyncStream<[UInt8]>

    private struct State {
        var exit: ProcessExit?
        var waiters: [CheckedContinuation<ProcessExit, Never>] = []
        var processSource: DispatchSourceProcess?
        var readSource: DispatchSourceRead?
        var readSuspended = false
    }

    private let state = Mutex(State())
    /// Bytes yielded on `output` that the consumer has not reported as consumed.
    private let backlog = Mutex(0)
    public static let maxBacklogBytes = 4 << 20
    public var backlogBytes: Int { backlog.withLock { $0 } }
    private let queue: DispatchQueue

    public static func launch(_ configuration: LaunchConfiguration) throws -> ProcessRunner {
        let (pid, master) = try PTYSpawner.spawn(configuration)
        return ProcessRunner(pid: pid, master: master)
    }

    private init(pid: pid_t, master: Int32) {
        self.pid = pid
        self.queue = DispatchQueue(label: "ampersand.process.\(pid)")
        let (stream, continuation) = AsyncStream<[UInt8]>.makeStream()
        self.output = stream

        let flags = fcntl(master, F_GETFL)
        _ = fcntl(master, F_SETFL, flags | O_NONBLOCK)

        let readSource = DispatchSource.makeReadSource(fileDescriptor: master, queue: queue)
        readSource.setEventHandler {
            // Drain everything available, then yield once: pty reads are often a single line.
            var buffer = [UInt8](repeating: 0, count: 16_384)
            var collected: [UInt8] = []
            defer {
                if !collected.isEmpty {
                    self.backlogAdd(collected.count)
                    continuation.yield(collected)
                    self.pauseReadingIfBackedUp()
                }
            }
            while collected.count < 1_048_576 {
                let count = Darwin.read(master, &buffer, buffer.count)
                if count > 0 {
                    collected.append(contentsOf: buffer[0..<count])
                    continue
                }
                if count < 0 && (errno == EAGAIN || errno == EINTR) { return }
                readSource.cancel()   // EOF or EIO: every writer has closed the pty
                return
            }
        }
        readSource.setCancelHandler {
            close(master)
            continuation.finish()
        }

        let processSource = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: queue)
        processSource.setEventHandler { [weak self] in self?.reap() }
        state.withLock {
            $0.processSource = processSource
            $0.readSource = readSource
        }

        readSource.resume()
        processSource.resume()
        queue.async { [weak self] in self?.reap() }   // the child may have exited before the source armed
    }

    public var exitStatus: ProcessExit? { state.withLock { $0.exit } }

    public func consumed(_ byteCount: Int) {
        let remaining = backlog.withLock { $0 -= byteCount; return $0 }
        if remaining < Self.maxBacklogBytes / 2 { resumeReading() }
    }

    /// Like a terminal: when the consumer falls behind, stop reading so the child blocks on write
    /// instead of Ampersand buffering without limit.
    private func pauseReadingIfBackedUp() {
        guard backlogBytes > Self.maxBacklogBytes else { return }
        let source = state.withLock { s -> DispatchSourceRead? in
            guard !s.readSuspended, let source = s.readSource else { return nil }
            s.readSuspended = true
            return source
        }
        source?.suspend()
    }

    private func resumeReading() {
        let source = state.withLock { s -> DispatchSourceRead? in
            guard s.readSuspended, let source = s.readSource else { return nil }
            s.readSuspended = false
            return source
        }
        source?.resume()
    }

    private func backlogAdd(_ byteCount: Int) {
        backlog.withLock { $0 += byteCount }
    }

    public func waitForExit() async -> ProcessExit {
        await withCheckedContinuation { continuation in
            let finished = state.withLock { s -> ProcessExit? in
                if let exit = s.exit { return exit }
                s.waiters.append(continuation)
                return nil
            }
            if let finished { continuation.resume(returning: finished) }
        }
    }

    @discardableResult
    public func terminate(grace: Duration = .seconds(5)) async -> ProcessExit {
        if let exit = exitStatus {
            signalGroup(SIGKILL)
            return exit
        }
        signalGroup(SIGTERM)
        return await withTaskGroup(of: ProcessExit?.self) { group in
            group.addTask { await self.waitForExit() }
            group.addTask {
                try? await Task.sleep(for: grace)
                return nil
            }
            if let first = await group.next(), let exit = first {
                group.cancelAll()
                signalGroup(SIGKILL)   // leftovers that ignored SIGTERM
                return exit
            }
            signalGroup(SIGKILL)
            for await result in group {
                if let exit = result { return exit }
            }
            return await waitForExit()
        }
    }

    private func signalGroup(_ signal: Int32) {
        _ = kill(-pid, signal)
    }

    private func reap() {
        var status: Int32 = 0
        guard waitpid(pid, &status, WNOHANG) == pid else { return }
        let exit = ProcessExit(waitStatus: status)
        let waiters = state.withLock { s -> [CheckedContinuation<ProcessExit, Never>] in
            guard s.exit == nil else { return [] }
            s.exit = exit
            s.processSource?.cancel()
            s.processSource = nil
            let pending = s.waiters
            s.waiters = []
            return pending
        }
        waiters.forEach { $0.resume(returning: exit) }
        resumeReading()

        // The leader is gone: ask leftovers to stop, then force them.
        signalGroup(SIGTERM)
        let pgid = pid
        queue.asyncAfter(deadline: .now() + 2) {
            if processGroupIsAlive(pgid) { _ = kill(-pgid, SIGKILL) }
        }
    }
}
