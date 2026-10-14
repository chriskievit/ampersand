import AmpersandCore
import AppKit
import SwiftUI

/// A group's name and the working directory its commands inherit when they have none of their own.
struct GroupSettingsSheet: View {
    let model: AppModel
    let group: GroupSpec
    @State private var name: String
    @State private var cwd: String
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, group: GroupSpec) {
        self.model = model
        self.group = group
        _name = State(initialValue: group.name)
        _cwd = State(initialValue: group.cwd ?? "")
    }

    private var problem: String? { WorkingDirectory.problem(cwd) }
    private var canSave: Bool { problem == nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Group") {
                    TextField("Name", text: $name)
                }
                Section {
                    LabeledContent("Working directory") {
                        HStack {
                            TextField("Working directory", text: $cwd, prompt: Text("Not set"))
                                .labelsHidden()
                            Button("Choose…") { chooseFolder() }
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text(problem ?? "Commands in this group run here unless they have a working directory of their own.")
                        .foregroundStyle(.secondary)
                }
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    cwd = (url.path as NSString).abbreviatingWithTildeInPath
                    return true
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    model.updateGroup(group.id, name: name, cwd: cwd)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 480, height: 300)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Use folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        cwd = (url.path as NSString).abbreviatingWithTildeInPath
    }
}
