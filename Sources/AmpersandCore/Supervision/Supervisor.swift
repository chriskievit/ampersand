import Darwin
import Foundation

/// Owns one command's process, state machine, restart policy and log.
public actor Supervisor {
    public nonisolated let id: UUID
    public nonisolated let events: AsyncStream<SupervisorEvent>

    private let eventContinuation: AsyncStream<SupervisorEvent>.Continuation
    private let launcher: any ProcessLaunching
    private let clock: any Clock
    private let stopGrace: Duration
    private let baseEnvironment: @Sendable () -> [String: String]

    private var spec: CommandSpec
    private var policy = RestartPolicy()
    private var log = LogBuffer()
    private var process: (any RunningProcess)?
    private var runID = 0
    private var startedAt: Date?
    private var stopRequested = false
    private var backoffTask: Task<Void, Never>?
    /// The termination in flight, so a second stop (or quit) waits for the group to die.
    private var stopTask: Task<Void, Never>?
    /// Output collected since the last `.output` event; flushed every ~50 ms so a noisy
    /// command produces a bounded number of events (spec 5.3).
    private var pendingLines: [String] = []
    private var flushScheduled = false
    private static let outputBatchInterval: Duration = .milliseconds(50)

    public private(set) var status: CommandStatus = .stopped {
        didSet { if status != oldValue { eventContinuation.yield(.status(status)) } }
    }

    public init(spec: CommandSpec,
                launcher: any ProcessLaunching = PTYProcessLauncher(),
                clock: any Clock = SystemClock(),
                stopGrace: Duration = .seconds(5),
                baseEnvironment: @escaping @Sendable () -> [String: String] = { ProcessInfo.processInfo.environment }) {
        self.id = spec.id
        self.spec = spec
        self.launcher = launcher
        self.clock = clock
        self.stopGrace = stopGrace
        self.baseEnvironment = baseEnvironment
        (events, eventContinuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
    }

    public var currentPID: pid_t? {
        guard let process, process.exitStatus == nil else { return nil }
        return process.pid
    }

    public var currentSpec: CommandSpec { spec }

    public func update(spec newSpec: CommandSpec) { spec = newSpec }

    public func logSnapshot() -> (lines: [String], partialLine: String) { (log.lines, log.partialLine) }

    public func clearLog() {
        log.clear()
        pendingLines.removeAll()
        eventContinuation.yield(.logCleared)
    }

    /// User-initiated start: clears restart history.
    public func start() {
        switch status.kind {
        case .starting, .running, .stopping: return
        case .backoff: backoffTask?.cancel(); backoffTask = nil
        default: break
        }
        policy.reset()
        launch()
    }

    public func stop() async {
        backoffTask?.cancel()
        backoffTask = nil
        switch status.kind {
        case .stopped:
            return
        case .stopping:
            await stopTask?.value
        case .backoff, .exited, .gaveUp, .failed:
            status = .stopped
        case .starting, .running:
            guard let process else { status = .stopped; return }
            stopRequested = true
            status = .stopping
            let grace = stopGrace
            let task = Task { _ = await process.terminate(grace: grace) }
            stopTask = task
            await task.value
            stopTask = nil
        }
        if status.kind == .stopping { status = .stopped }
    }

    public func restart() async {
        await stop()
        start()
    }

    public func markHealthy() {
        if case .starting(let since) = status { status = .running(since: since) }
    }

    public func shutdown() async {
        await stop()
        eventContinuation.finish()
    }

    // MARK: - Internals

    private func launch() {
        runID += 1
        let run = runID
        stopRequested = false

        var envFileContents: String?
        if let path = spec.envFile {
            guard let text = try? String(contentsOfFile: (path as NSString).expandingTildeInPath, encoding: .utf8) else {
                status = .failedToStart(.envFileUnreadable(path))
                return
            }
            envFileContents = text
        }

        let configuration = LaunchConfiguration.make(spec: spec, baseEnvironment: baseEnvironment(),
                                                     envFileContents: envFileContents)
        let newProcess: any RunningProcess
        do {
            newProcess = try launcher.launch(configuration)
        } catch SpawnError.cwdMissing(let path) {
            status = .failedToStart(.folderMissing(path))
            return
        } catch {
            status = .failedToStart(.spawnFailed(String(describing: error)))
            return
        }

        process = newProcess
        let now = clock.now
        startedAt = now
        status = .starting(since: now)

        Task {
            for await chunk in newProcess.output { self.ingest(chunk, run: run) }
        }
        Task {
            let exit = await newProcess.waitForExit()
            self.handleExit(exit, run: run)
        }
        Task { [clock] in
            try? await clock.sleep(for: .seconds(1))
            self.promote(run: run)
        }
    }

    private func ingest(_ chunk: [UInt8], run: Int) {
        guard run == runID else { return }
        pendingLines += log.append(chunk)
        guard !flushScheduled else { return }
        flushScheduled = true
        Task {
            try? await Task.sleep(for: Self.outputBatchInterval)
            self.flushOutput()
        }
    }

    private func flushOutput() {
        flushScheduled = false
        guard !pendingLines.isEmpty || !log.partialLine.isEmpty else { return }
        eventContinuation.yield(.output(newLines: pendingLines, partialLine: log.partialLine))
        pendingLines.removeAll(keepingCapacity: true)
    }

    private func promote(run: Int) {
        guard run == runID, case .starting(let since) = status else { return }
        status = .running(since: since)
    }

    private func handleExit(_ exit: ProcessExit, run: Int) {
        guard run == runID else { return }
        flushOutput()   // the last lines (often the error) arrive before the exit status
        let now = clock.now
        if stopRequested {
            status = .stopped
            return
        }
        guard spec.restart else {
            status = .exited(exit, at: now)
            return
        }
        let uptime = now.timeIntervalSince(startedAt ?? now)
        switch policy.recordCrash(at: now, uptime: uptime) {
        case .giveUp:
            status = .gaveUp(exit: exit, at: now)
        case .restart(let delay):
            status = .backoff(exit: exit, at: now,
                              restartAt: now.addingTimeInterval(TimeInterval(delay.components.seconds)))
            backoffTask = Task { [clock] in
                do { try await clock.sleep(for: delay) } catch { return }
                self.restartAfterBackoff(run: run)
            }
        }
    }

    private func restartAfterBackoff(run: Int) {
        guard run == runID, status.kind == .backoff else { return }
        launch()
    }
}
