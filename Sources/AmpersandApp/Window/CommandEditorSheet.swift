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
            CommandForm(draft: $draft, model: model, title: title, focusCommand: true) {
                EmptyView()
            } footer: {
                if let runtime = session.runtime { RunOnceSection(runtime: runtime) }
            }
            Divider()
            HStack {
                Button(session.isRunning ? "Stop Test" : "Run Once") {
                    session.isRunning ? session.stop() : session.run(draft.makeSpec(), model: model)
                }
                .disabled(!draft.isValid)
                Spacer()
                Button("Cancel", role: .cancel) { cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
            }
            .padding()
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 420, idealHeight: 640)
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
        guard model.save(spec) else { return }   // the window's banner says why; keep the edits
        model.windowSelection = spec.id
        close()
    }

    private func close() {
        session.close(model: model)
        model.editorRequest = nil
        dismiss()
    }
}
