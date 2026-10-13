import AmpersandCore
import AppKit
import SwiftUI

/// Fields for adding or editing a command (spec 6.1), as a native grouped form: titled
/// sections, label-left/value-right rows, everything visible (System Settings style).
/// `header` and `footer` add context sections (notices, the Run Once console).
struct CommandForm<Header: View, Footer: View>: View {
    @Binding var draft: CommandDraft
    let model: AppModel
    /// Heading of the first section: "Command" in the window, the sheet's title in a sheet.
    var title = "Command"
    /// Sheets put the cursor in the command field, like any native sheet's first field.
    var focusCommand = false
    @ViewBuilder var header: () -> Header
    @ViewBuilder var footer: () -> Footer
    @FocusState private var commandFocused: Bool
    @State private var askingForGroup = false
    @State private var newGroupName = ""

    private static var newGroupTag: String { "__new_group__" }

    var body: some View {
        Form {
            header()
            commandSection
            Section {
                TextField("Name", text: $draft.name, prompt: Text(namePrompt))
                Picker("Group", selection: groupSelection) {
                    Text("No Group").tag(String?.none)
                    ForEach(model.config.groups) { group in
                        Text(group.name).tag(String?.some(group.id))
                    }
                    Divider()
                    Text("New Group…").tag(String?.some(Self.newGroupTag))
                }
            }
            Section("Location") {
                LabeledContent("Working Directory") {
                    HStack {
                        TextField("Working Directory", text: $draft.cwd, prompt: Text("Not set"))
                            .labelsHidden()
                        Button("Choose…") { chooseFolder() }
                    }
                }
                LabeledContent("Environment File") {
                    if draft.envFile.isEmpty {
                        Button("Choose…") { chooseEnvFile() }
                    } else {
                        HStack {
                            Text(draft.envFile)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button("Remove") { draft.envFile = "" }
                        }
                    }
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                if let url = urls.first { draft.cwd = (url.path as NSString).abbreviatingWithTildeInPath }
            }
            EnvironmentSection(envText: $draft.envText)
            Section("Network") {
                TextField("Port", text: $draft.portText,
                          prompt: Text(draft.makeSpec().port.map(String.init) ?? "None"))
                Picker("Health Check", selection: $draft.health) {
                    Text("None").tag(HealthChoice.none)
                    Text("Port Accepts Connections").tag(HealthChoice.port)
                    Text("URL Responds").tag(HealthChoice.url)
                }
                if draft.health == .url {
                    TextField("URL", text: $draft.healthURL, prompt: Text(verbatim: "http://localhost:3000/health"))
                }
            }
            Section("Startup") {
                Toggle("Start when Ampersand launches", isOn: $draft.autoStart)
                Toggle("Restart on crash", isOn: $draft.restart)
            }
            footer()
        }
        .formStyle(.grouped)
        .alert("New Group", isPresented: $askingForGroup) {
            TextField("Name", text: $newGroupName)
            Button("Create") { draft.group = model.addGroup(named: newGroupName).id }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// The command line gets a full-width, left-aligned row: it is code, not a value.
    private var commandSection: some View {
        Section {
            TextField("Command", text: $draft.commandText, prompt: Text(verbatim: "npm run dev"), axis: .vertical)
                .labelsHidden()
                .focused($commandFocused)
                .onAppear { if focusCommand { commandFocused = true } }
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.leading)
                .lineLimit(1...6)
            if !draft.suggestions.isEmpty {
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
        } header: {
            Text(title)
        } footer: {
            if let message = draft.validationMessage, !draft.commandText.isEmpty {
                Text(message).foregroundStyle(.secondary)
            } else if !draft.suggestions.isEmpty {
                Text("Detected from the command. Remove anything you don’t want.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var namePrompt: String {
        draft.commandText.trimmingCharacters(in: .whitespaces).isEmpty ? "From the command" : draft.makeSpec().name
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

    private func chooseEnvFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.prompt = "Use File"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        draft.envFile = (url.path as NSString).abbreviatingWithTildeInPath
    }
}

extension CommandForm where Header == EmptyView, Footer == EmptyView {
    init(draft: Binding<CommandDraft>, model: AppModel) {
        self.init(draft: draft, model: model, title: "Command", focusCommand: false, header: { EmptyView() }, footer: { EmptyView() })
    }
}
