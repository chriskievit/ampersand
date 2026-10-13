import AmpersandCore
import SwiftUI

struct CommandEditorSheet: View {
    let model: AppModel
    let original: CommandSpec?
    @State private var draft: CommandDraft
    @State private var session = RunOnceSession()
    @State private var confirmingDiscard = false
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, original: CommandSpec?) {
        self.model = model
        self.original = original
        _draft = State(initialValue: original.map(CommandDraft.init(spec:)) ?? CommandDraft(restartDefault: AppDefaults.restartOnCrash))
    }

    private var title: String { original.map { "Edit “\($0.name)”" } ?? "New Command" }

    private var isDirty: Bool {
        if let original { return draft.makeSpec() != original }
        return !draft.commandText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.top, 16)
            CommandForm(draft: $draft, model: model, expanded: original != nil)
            if let runtime = session.runtime {
                Divider()
                RunOnceConsole(runtime: runtime)
                    .frame(height: 180)
            }
            Divider()
            HStack {
                Button(session.isRunning ? "Stop Test" : "Run Once") {
                    session.isRunning ? session.stop() : session.run(draft.makeSpec(), model: model)
                }
                .disabled(!draft.isValid)
                if let message = draft.validationMessage, !draft.commandText.isEmpty {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button("Cancel", role: .cancel) { cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
            }
            .padding(16)
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 420, idealHeight: 560)
        .interactiveDismissDisabled(isDirty)
        .confirmationDialog(original.map { "Save changes to “\($0.name)”?" } ?? "Save this command?",
                            isPresented: $confirmingDiscard) {
            Button("Save") { save() }
                .disabled(!draft.isValid)
            Button("Discard Changes", role: .destructive) { close() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your changes haven’t been saved.")
        }
        .onDisappear { session.close(model: model) }
    }

    private func cancel() {
        if isDirty { confirmingDiscard = true } else { close() }
    }

    private func save() {
        let spec = draft.makeSpec()
        model.save(spec)
        model.windowSelection = spec.id
        close()
    }

    private func close() {
        session.close(model: model)
        model.editorRequest = nil
        dismiss()
    }
}
