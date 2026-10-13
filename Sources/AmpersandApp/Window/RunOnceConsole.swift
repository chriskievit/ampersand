import AmpersandCore
import SwiftUI

/// Runs the draft once, outside the config, so the user sees it work before saving (spec 6.1).
@MainActor @Observable
final class RunOnceSession {
    private(set) var runtime: CommandRuntime?

    var isRunning: Bool { runtime?.status.isActive ?? false }

    /// Runs through the model so quit and crash cleanup know about the process.
    func run(_ spec: CommandSpec, model: AppModel) {
        close(model: model)
        var once = spec
        once.id = UUID()
        once.restart = false
        let runtime = model.makeTransientRuntime(once)
        self.runtime = runtime
        Task { await runtime.supervisor.start() }
    }

    func stop() {
        guard let runtime, runtime.status.isActive else { return }
        Task { await runtime.supervisor.stop() }
    }

    /// Stops the process (if any) and hands it to the model to finish shutting down.
    func close(model: AppModel) {
        guard let runtime else { return }
        model.retireTransient(runtime)
        self.runtime = nil
    }
}

/// The Run Once output as a form section: a status row and the live log.
struct RunOnceSection: View {
    let runtime: CommandRuntime

    var body: some View {
        Section("Test run") {
            LabeledContent("Status") {
                HStack(spacing: 6) {
                    StatusGlyph(kind: runtime.status.kind, healthFailing: false)
                    Text(StatusText.stamp(for: runtime.status, now: Date()) ?? StatusText.stateWord(runtime.status.kind))
                }
            }
            LogView(runtime: runtime, totalCommitted: runtime.totalCommitted, partialLine: runtime.partialLine,
                    generation: runtime.logGeneration, follow: .constant(true))
                .frame(height: 160)
        }
    }
}
