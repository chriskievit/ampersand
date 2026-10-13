import Darwin
import Foundation

public struct LaunchConfiguration: Sendable, Equatable {
    public static let defaultShellFlags = ["-l", "-i", "+m", "-c"]

    public var shell: String
    public var shellFlags: [String]
    public var command: String
    public var cwd: String?
    public var environment: [String: String]

    public init(shell: String, shellFlags: [String] = LaunchConfiguration.defaultShellFlags,
                command: String, cwd: String?, environment: [String: String]) {
        self.shell = shell; self.shellFlags = shellFlags; self.command = command
        self.cwd = cwd; self.environment = environment
    }

    /// Merge order: base environment, terminal variables, the spec's env text, the env file.
    public static func make(spec: CommandSpec, baseEnvironment: [String: String], envFileContents: String?) -> LaunchConfiguration {
        var env = baseEnvironment
        env["TERM"] = "xterm-256color"
        env["FORCE_COLOR"] = "1"
        env.merge(EnvParser.parse(spec.env).values) { $1 }
        if let envFileContents { env.merge(EnvParser.parse(envFileContents).values) { $1 } }
        return LaunchConfiguration(shell: supportedShell(baseEnvironment["SHELL"]),
                                   command: spec.command, cwd: spec.expandedCwd, environment: env)
    }

    /// zsh and bash understand `-l -i +m -c`; anything else falls back to /bin/zsh.
    public static func supportedShell(_ shell: String?) -> String {
        guard let shell, ["zsh", "bash"].contains((shell as NSString).lastPathComponent) else { return "/bin/zsh" }
        return shell
    }
}

public enum SpawnError: Error, Equatable {
    case cwdMissing(String)
    case ptyUnavailable(Int32)
    case spawnFailed(Int32)
}

/// Spawns the shell on a new pty in a new session, so the child's pid is also its
/// process group id. Verified on macOS 26: isatty() is true in the child.
enum PTYSpawner {
    static func spawn(_ c: LaunchConfiguration, columns: UInt16 = 200, rows: UInt16 = 50) throws -> (pid: pid_t, master: Int32) {
        if let cwd = c.cwd {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: cwd, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw SpawnError.cwdMissing(cwd)
            }
        }

        let master = posix_openpt(O_RDWR | O_NOCTTY)
        guard master >= 0, grantpt(master) == 0, unlockpt(master) == 0, let namePointer = ptsname(master) else {
            let code = errno
            if master >= 0 { close(master) }
            throw SpawnError.ptyUnavailable(code)
        }
        let slaveName = String(cString: namePointer)
        var size = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(master, TIOCSWINSZ, &size)

        var actions: posix_spawn_file_actions_t? = nil
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, slaveName, O_RDWR, 0)
        posix_spawn_file_actions_adddup2(&actions, 0, 1)
        posix_spawn_file_actions_adddup2(&actions, 0, 2)
        if let cwd = c.cwd { posix_spawn_file_actions_addchdir(&actions, cwd) }

        var attributes: posix_spawnattr_t? = nil
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT))
        var defaultSignals = sigset_t()
        sigfillset(&defaultSignals)
        posix_spawnattr_setsigdefault(&attributes, &defaultSignals)
        var emptyMask = sigset_t()
        sigemptyset(&emptyMask)
        posix_spawnattr_setsigmask(&attributes, &emptyMask)

        var argv: [UnsafeMutablePointer<CChar>?] = ([c.shell] + c.shellFlags + [c.command]).map { strdup($0) } + [nil]
        var envp: [UnsafeMutablePointer<CChar>?] = c.environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }

        var pid: pid_t = 0
        let rc = posix_spawn(&pid, c.shell, &actions, &attributes, &argv, &envp)
        guard rc == 0 else {
            close(master)
            throw SpawnError.spawnFailed(rc)
        }
        return (pid, master)
    }
}
