import Darwin
import Foundation
import Testing
@testable import AmpersandCore

/// Sleeps `factor` times faster than real time; `now` stays real.
struct FastClock: Clock {
    let factor: Double
    var now: Date { Date() }
    func sleep(for duration: Duration) async throws { try await Task.sleep(for: duration / factor) }
}

/// Real processes, but zsh without rc files so tests stay fast.
struct FastLauncher: ProcessLaunching {
    func launch(_ configuration: LaunchConfiguration) throws -> any RunningProcess {
        var c = configuration
        c.shell = "/bin/zsh"
        c.shellFlags = ["-f", "+m", "-c"]
        return try ProcessRunner.launch(c)
    }
}

func makeSupervisor(_ command: String, restart: Bool = true, cwd: String? = nil, envFile: String? = nil,
                    factor: Double = 10) -> Supervisor {
    Supervisor(spec: CommandSpec(name: "t", command: command, cwd: cwd, envFile: envFile, restart: restart),
               launcher: FastLauncher(), clock: FastClock(factor: factor), stopGrace: .seconds(1))
}

func eventually(_ s: Supervisor, timeout: Duration = .seconds(3), _ kind: CommandStatus.Kind) async -> Bool {
    await waitUntil(timeout: timeout) { await s.status.kind == kind }
}

@Suite(.serialized) struct SupervisorTests {
    @Test func startRunsPromotesAndStops() async throws {
        let s = makeSupervisor("sleep 30")
        await s.start()
        #expect(await s.status.kind == .starting)
        #expect(await eventually(s, .running))
        let pid = try #require(await s.currentPID)
        await s.stop()
        #expect(await s.status == .stopped)
        #expect(await s.currentPID == nil)
        #expect(await waitUntil { !processGroupIsAlive(pid) })
    }

    @Test func outputReachesLogAndEvents() async throws {
        let s = makeSupervisor("echo hello-amp; sleep 5")
        let seen = Task {
            for await event in s.events {
                if case .output(let lines, _) = event, lines.contains(where: { $0.contains("hello-amp") }) { return true }
            }
            return false
        }
        await s.start()
        #expect(await waitUntil { await s.logSnapshot().lines.contains { $0.contains("hello-amp") } })
        #expect(await seen.value)
        await s.shutdown()
    }

    @Test func instantExitIsCrash() async throws {
        let s = makeSupervisor("exit 4", restart: false)
        await s.start()
        #expect(await eventually(s, .exited))
        guard case .exited(let exit, _) = await s.status else { Issue.record("not exited"); return }
        #expect(exit == .exited(4))
    }

    @Test func crashLoopBacksOffThenGivesUp() async throws {
        let s = makeSupervisor("exit 1", factor: 100)
        let kinds = Task {
            var seen: [CommandStatus.Kind] = []
            for await event in s.events {
                if case .status(let status) = event {
                    seen.append(status.kind)
                    if status.kind == .gaveUp { break }
                }
            }
            return seen
        }
        await s.start()
        #expect(await eventually(s, timeout: .seconds(10), .gaveUp))
        let seen = await kinds.value
        #expect(seen.filter { $0 == .backoff }.count == 4)
    }

    @Test func stopDuringBackoffCancelsRestart() async throws {
        let s = makeSupervisor("exit 1", factor: 4)   // first backoff lasts 250 ms
        await s.start()
        #expect(await eventually(s, .backoff))
        await s.stop()
        #expect(await s.status == .stopped)
        try await Task.sleep(for: .milliseconds(600))
        #expect(await s.status == .stopped)
        #expect(await s.currentPID == nil)
    }

    @Test func explicitStopNeverRestarts() async throws {
        let s = makeSupervisor("sleep 30", factor: 100)
        await s.start()
        #expect(await eventually(s, .running))
        await s.stop()
        try await Task.sleep(for: .milliseconds(200))
        #expect(await s.status == .stopped)
    }

    @Test func folderMissingFailsToStart() async {
        let s = makeSupervisor("true", cwd: "/no/such/folder")
        await s.start()
        #expect(await s.status == .failedToStart(.folderMissing("/no/such/folder")))
        await s.stop()
        #expect(await s.status == .stopped)
    }

    @Test func unreadableEnvFileFailsToStart() async {
        let s = makeSupervisor("true", envFile: "/no/such/.env")
        await s.start()
        #expect(await s.status == .failedToStart(.envFileUnreadable("/no/such/.env")))
    }

    @Test func startIsIdempotentAndRestartGivesNewProcess() async throws {
        let s = makeSupervisor("sleep 30")
        await s.start()
        let first = try #require(await s.currentPID)
        await s.start()
        #expect(await s.currentPID == first)
        await s.restart()
        let second = try #require(await s.currentPID)
        #expect(second != first)
        await s.shutdown()
    }

    @Test func markHealthyPromotesImmediately() async throws {
        let s = makeSupervisor("sleep 30", factor: 1)   // the 1 s promotion takes a real second
        await s.start()
        await s.markHealthy()
        #expect(await s.status.kind == .running)
        await s.shutdown()
    }
}

@Suite(.serialized) struct SupervisorStoppingTests {
    @Test func secondStopWaitsForTheGroupToDie() async throws {
        let s = makeSupervisor("trap '' TERM; sleep 30")   // stopGrace 1 s, then SIGKILL
        await s.start()
        #expect(await eventually(s, .running))
        let pid = try #require(await s.currentPID)
        let first = Task { await s.stop() }
        #expect(await eventually(s, .stopping))
        await s.stop()   // e.g. Quit pressed while the first Stop is still waiting
        #expect(!processGroupIsAlive(pid))
        #expect(await s.status == .stopped)
        await first.value
    }

    @Test func restartWhileStoppingStartsAgain() async throws {
        let s = makeSupervisor("trap '' TERM; sleep 30")
        await s.start()
        #expect(await eventually(s, .running))
        let old = try #require(await s.currentPID)
        let first = Task { await s.stop() }
        #expect(await eventually(s, .stopping))
        await s.restart()
        let new = try #require(await s.currentPID)
        #expect(new != old)
        await first.value
        await s.shutdown()
    }
}

@Suite(.serialized) struct SupervisorFloodTests {
    @Test func floodIsBatchedBeforeLeavingTheActor() async throws {
        let s = makeSupervisor("yes amp | head -n 60000; sleep 5")
        let counts = Task {
            var events = 0, lines = 0
            for await event in s.events {
                if case .output(let newLines, _) = event {
                    events += 1
                    lines += newLines.count
                    if lines >= 60_000 { break }
                }
            }
            return (events, lines)
        }
        await s.start()
        let (events, lines) = await counts.value
        #expect(lines == 60_000)
        #expect(events < 200)   // ~50 ms batches, not one event per pty read
        await s.shutdown()
    }
}

@Suite(.serialized) struct SupervisorCleanExitTests {
    @Test func cleanExitFinishesQuietlyAndIsNotRestarted() async throws {
        let s = makeSupervisor("exit 0", restart: true, factor: 100)
        await s.start()
        #expect(await eventually(s, .finished))
        try await Task.sleep(for: .milliseconds(300))   // a restart would have happened by now
        #expect(await s.status.kind == .finished)
        #expect(await s.currentPID == nil)
        #expect(await s.status.isActive == false)
    }
}
