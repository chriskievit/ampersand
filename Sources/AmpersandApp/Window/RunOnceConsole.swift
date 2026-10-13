import AmpersandCore
import SwiftUI

/// Runs the draft once, outside the config, so the user sees it work before saving (spec 6.1).
@MainActor @Observable
final class RunOnceSession {
    private(set) var runtime: CommandRuntime?
    @ObservationIgnored private var eventTask: Task<Void, Never>?

    var isRunning: Bool { runtime?.status.isActive ?? false }

    func run(_ spec: CommandSpec) {
        stop()
        var once = spec
        once.id = UUID()
        once.restart = false
        let supervisor = Supervisor(spec: once)
        let runtime = CommandRuntime(spec: once, supervisor: supervisor)
        self.runtime = runtime
        eventTask = Task {
            for await event in supervisor.events {
                switch event {
                case .status(let status): runtime.status = status
                case .output(let lines, let partial): runtime.receive(newLines: lines, partialLine: partial)
                case .logCleared: break
                }
            }
        }
        Task { await supervisor.start() }
    }

    func stop() {
        guard let runtime, runtime.status.isActive else { return }
        Task { await runtime.supervisor.stop() }
    }
}

struct RunOnceConsole: View {
    let runtime: CommandRuntime

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                StatusGlyph(kind: runtime.status.kind, healthFailing: false)
                Text(StatusText.stamp(for: runtime.status, now: Date()) ?? StatusText.stateWord(runtime.status.kind))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            LogView(runtime: runtime, totalCommitted: runtime.totalCommitted, partialLine: runtime.partialLine,
                    generation: runtime.logGeneration, follow: .constant(true))
        }
    }
}
