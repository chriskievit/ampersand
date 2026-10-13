import Darwin
import Foundation
import Testing
@testable import AmpersandCore

/// Fast launches for tests: zsh without rc files (-f), job control off.
func testLaunch(_ command: String, env: [String: String] = [:], cwd: String? = nil) throws -> ProcessRunner {
    var environment = ProcessInfo.processInfo.environment
    environment.merge(env) { $1 }
    return try ProcessRunner.launch(LaunchConfiguration(
        shell: "/bin/zsh", shellFlags: ["-f", "+m", "-c"], command: command, cwd: cwd, environment: environment))
}

func collectOutput(_ runner: ProcessRunner) async -> String {
    var bytes: [UInt8] = []
    for await chunk in runner.output { bytes += chunk }
    return String(decoding: bytes, as: UTF8.self)
}

func waitUntil(timeout: Duration = .seconds(3), _ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(25))
    }
    return await condition()
}

@Suite(.serialized) struct ProcessRunnerTests {
    @Test func echoesOutputAndExitCode() async throws {
        let r = try testLaunch("echo hello; exit 3")
        let out = await collectOutput(r)
        #expect(out.contains("hello"))
        #expect(await r.waitForExit() == .exited(3))
    }

    @Test func outputIsATTYWithRealShellFlags() async throws {
        let r = try ProcessRunner.launch(LaunchConfiguration(
            shell: "/bin/zsh", command: "[ -t 1 ] && echo is-a-tty", cwd: nil,
            environment: ProcessInfo.processInfo.environment))
        #expect(await collectOutput(r).contains("is-a-tty"))
        #expect(await r.waitForExit() == .exited(0))
    }

    @Test func cwdWithSpaces() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("amp dir \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let r = try testLaunch("pwd", cwd: dir.path)
        #expect(await collectOutput(r).contains(dir.lastPathComponent))
    }

    @Test func missingCwdThrows() {
        #expect(throws: SpawnError.cwdMissing("/definitely/not/here")) {
            _ = try testLaunch("true", cwd: "/definitely/not/here")
        }
    }

    @Test func environmentIsPassed() async throws {
        let r = try testLaunch("echo value=$AMP_TEST", env: ["AMP_TEST": "a b"])
        #expect(await collectOutput(r).contains("value=a b"))
    }

    @Test func trapsTermIsKilled() async throws {
        let r = try testLaunch("trap '' TERM; sleep 30")
        try await Task.sleep(for: .milliseconds(200))
        let started = ContinuousClock.now
        let exit = await r.terminate(grace: .milliseconds(500))
        #expect(exit == .signaled(SIGKILL))
        #expect(ContinuousClock.now - started < .seconds(3))
        #expect(await waitUntil { !processGroupIsAlive(r.pid) })
    }

    @Test func grandchildrenDie() async throws {
        let r = try testLaunch("sleep 30 & sleep 30 & wait")
        try await Task.sleep(for: .milliseconds(200))
        await r.terminate(grace: .seconds(2))
        #expect(await waitUntil { !processGroupIsAlive(r.pid) })
    }

    @Test func leaderExitCleansUpLeftovers() async throws {
        let r = try testLaunch("sleep 30 & exit 0")
        #expect(await r.waitForExit() == .exited(0))
        #expect(await waitUntil(timeout: .seconds(4)) { !processGroupIsAlive(r.pid) })
    }

    @Test func floodDoesNotBlock() async throws {
        let r = try testLaunch("yes amp | head -n 100000")
        let started = ContinuousClock.now
        let out = await collectOutput(r)
        #expect(await r.waitForExit() == .exited(0))
        #expect(ContinuousClock.now - started < .seconds(10))
        #expect(out.components(separatedBy: "amp").count - 1 == 100000)
    }

    @Test func launchConfigurationMergeOrder() {
        let spec = CommandSpec(name: "x", command: "run", cwd: "~/w", env: "A=spec\nB=spec")
        let c = LaunchConfiguration.make(spec: spec, baseEnvironment: ["A": "base", "SHELL": "/bin/bash", "PATH": "/bin"],
                                         envFileContents: "B=file")
        #expect(c.environment["A"] == "spec")
        #expect(c.environment["B"] == "file")
        #expect(c.environment["PATH"] == "/bin")
        #expect(c.environment["TERM"] == "xterm-256color")
        #expect(c.environment["FORCE_COLOR"] == "1")
        #expect(c.shell == "/bin/bash")
        #expect(c.shellFlags == ["-l", "-i", "+m", "-c"])
        #expect(c.cwd == NSHomeDirectory() + "/w")
        #expect(LaunchConfiguration.supportedShell("/opt/homebrew/bin/fish") == "/bin/zsh")
        #expect(LaunchConfiguration.supportedShell(nil) == "/bin/zsh")
    }
}
