import AmpersandCore
import SwiftUI

/// The window's Settings tab: the command's form, applied as you edit (System Settings style).
/// Each pause in editing is one Undo step; nothing restarts on its own (spec 6.3).
struct CommandSettingsPane: View {
    let runtime: CommandRuntime
    let model: AppModel
    @State private var draft: CommandDraft
    @State private var lastApplied: CommandSpec
    @State private var applyTask: Task<Void, Never>?

    init(runtime: CommandRuntime, model: AppModel) {
        self.runtime = runtime
        self.model = model
        _draft = State(initialValue: CommandDraft(spec: runtime.spec))
        _lastApplied = State(initialValue: runtime.spec)
    }

    var body: some View {
        CommandForm(draft: $draft, model: model) {
            if runtime.needsRestartToApply {
                Section {
                    LabeledContent {
                        Button("Restart") { model.restart(runtime.id) }
                    } label: {
                        Label("Restart to apply your changes.", systemImage: "arrow.clockwise.circle")
                    }
                }
            }
        } footer: {
            EmptyView()
        }
        .onChange(of: draft) { _, newDraft in scheduleApply(newDraft) }
        .onChange(of: runtime.spec) { _, spec in
            // Changed elsewhere (Undo, a move in the sidebar, the editor sheet): show it.
            guard spec != lastApplied else { return }
            applyTask?.cancel()
            lastApplied = spec
            draft = CommandDraft(spec: spec)
        }
        .onDisappear { applyNow(draft) }
    }

    private func scheduleApply(_ newDraft: CommandDraft) {
        applyTask?.cancel()
        applyTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            applyNow(newDraft)
        }
    }

    private func applyNow(_ current: CommandDraft) {
        applyTask?.cancel()
        guard current.isValid else { return }   // the form shows why
        let spec = current.makeSpec()
        guard spec != lastApplied else { return }
        let previous = lastApplied
        lastApplied = spec
        if !model.applyEdit(spec, previous: previous) { lastApplied = previous }
    }
}
