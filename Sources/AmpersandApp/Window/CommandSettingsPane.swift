import AmpersandCore
import SwiftUI

/// The window's Settings tab: the same form, inline, with Revert and Save (spec 4.3).
struct CommandSettingsPane: View {
    let runtime: CommandRuntime
    let model: AppModel
    @State private var draft: CommandDraft

    init(runtime: CommandRuntime, model: AppModel) {
        self.runtime = runtime
        self.model = model
        _draft = State(initialValue: CommandDraft(spec: runtime.spec))
    }

    private var isDirty: Bool { draft.makeSpec() != runtime.spec }

    var body: some View {
        VStack(spacing: 0) {
            CommandForm(draft: $draft, model: model, expanded: true)
            Divider()
            HStack {
                if runtime.needsRestartToApply {
                    Text("Restart to apply your changes.")
                        .foregroundStyle(.secondary)
                    Button("Restart") { model.restart(runtime.id) }
                } else if let message = draft.validationMessage {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Revert") { draft = CommandDraft(spec: runtime.spec) }
                    .disabled(!isDirty)
                Button("Save") {
                    let spec = draft.makeSpec()
                    model.save(spec)
                    draft = CommandDraft(spec: spec)
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!isDirty || !draft.isValid)
            }
            .padding(16)
        }
    }
}
