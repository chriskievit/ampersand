import AmpersandCore
import AppKit
import SwiftUI

/// Fields for adding or editing a command (spec 6.1). One field is enough; the rest is under More.
struct CommandForm: View {
    @Binding var draft: CommandDraft
    let model: AppModel
    @State private var showMore: Bool
    @State private var askingForGroup = false
    @State private var newGroupName = ""

    private static let newGroupTag = "__new_group__"

    init(draft: Binding<CommandDraft>, model: AppModel, expanded: Bool) {
        _draft = draft
        self.model = model
        _showMore = State(initialValue: expanded)
    }

    var body: some View {
        Form {
            Section {
                TextField("Command", text: $draft.commandText, prompt: Text(verbatim: "npm run dev"), axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1...4)
                if !draft.suggestions.isEmpty {
                    LabeledContent("Detected") {
                        FlowLayout {
                            ForEach(draft.suggestions) { suggestion in
                                Button {
                                    draft.dismissedChips.insert(suggestion.chip)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(suggestion.label)
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Don’t use this")
                                .accessibilityLabel("\(suggestion.label). Remove")
                            }
                        }
                    }
                }
                TextField("Name", text: $draft.name, prompt: Text(draft.makeSpec().name))
                Picker("Group", selection: groupSelection) {
                    Text("No Group").tag(String?.none)
                    ForEach(model.config.groups) { group in
                        Text(group.name).tag(String?.some(group.id))
                    }
                    Divider()
                    Text("New Group…").tag(String?.some(Self.newGroupTag))
                }
            }
            Section {
                DisclosureGroup("More", isExpanded: $showMore) {
                    LabeledContent("Working Directory") {
                        HStack {
                            TextField("Working Directory", text: $draft.cwd, prompt: Text(verbatim: "~/dev/project"))
                                .labelsHidden()
                            Button("Choose…") { chooseFolder() }
                        }
                    }
                    .dropDestination(for: URL.self) { urls, _ in
                        if let url = urls.first { draft.cwd = (url.path as NSString).abbreviatingWithTildeInPath }
                    }
                    EnvEditor(text: $draft.envText, envFile: $draft.envFile, errors: draft.envErrors)
                    TextField("Port", text: $draft.portText,
                              prompt: Text(draft.makeSpec().port.map(String.init) ?? "None"))
                    Picker("Health Check", selection: $draft.health) {
                        Text("None").tag(HealthChoice.none)
                        Text("Port").tag(HealthChoice.port)
                        Text("URL").tag(HealthChoice.url)
                    }
                    .pickerStyle(.segmented)
                    if draft.health == .url {
                        TextField("URL", text: $draft.healthURL, prompt: Text(verbatim: "http://localhost:3000/health"))
                    }
                    Toggle("Start when Ampersand launches", isOn: $draft.autoStart)
                    Toggle("Restart on crash", isOn: $draft.restart)
                }
            }
        }
        .formStyle(.grouped)
        .alert("New Group", isPresented: $askingForGroup) {
            TextField("Name", text: $newGroupName)
            Button("Create") { draft.group = model.addGroup(named: newGroupName).id }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var groupSelection: Binding<String?> {
        Binding {
            draft.group
        } set: { value in
            if value == Self.newGroupTag {
                newGroupName = ""
                askingForGroup = true
            } else {
                draft.group = value
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Use Folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        draft.cwd = (url.path as NSString).abbreviatingWithTildeInPath
    }
}
