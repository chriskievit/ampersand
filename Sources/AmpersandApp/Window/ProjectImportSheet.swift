import AmpersandCore
import AppKit
import SwiftUI

/// Pick a folder, tick package.json scripts, get pre-filled commands (spec 6.2).
struct ProjectImportSheet: View {
    let model: AppModel
    @State private var folder: URL?
    @State private var project: DetectedProject?
    @State private var selected: Set<String> = []
    @State private var makeGroup = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Project folder") {
                        HStack {
                            if let folder {
                                Text((folder.path as NSString).abbreviatingWithTildeInPath)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Button(folder == nil ? "Choose…" : "Change…") { chooseFolder() }
                        }
                    }
                } header: {
                    Text("Add from project folder").font(.headline)
                } footer: {
                    if folder == nil {
                        Text("Choose or drop a folder that contains a package.json.")
                            .foregroundStyle(.secondary)
                    } else if project == nil {
                        Text("There’s no package.json in this folder. Choose another one, or add the command by hand.")
                            .foregroundStyle(.secondary)
                    }
                }
                if let project {
                    Section {
                        ForEach(project.scripts) { script in
                            Toggle(isOn: binding(for: script.name)) {
                                Text(script.name)
                                Text(script.body)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    } header: {
                        Text("\(project.name) · \(project.packageManager)")
                    } footer: {
                        Text("Ports are detected from each script where possible.")
                            .foregroundStyle(.secondary)
                    }
                    Section {
                        Toggle("Put them in a new group named “\(project.name)”", isOn: $makeGroup)
                            .disabled(selected.count < 2)
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                if folder != nil && project == nil {
                    Button("Add command…") { model.editorRequest = .new() }
                }
                Spacer()
                Button("Cancel", role: .cancel) { close() }
                    .keyboardShortcut(.cancelAction)
                Button(addTitle) { add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(project == nil || selected.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 360, idealHeight: 480)
        .dropDestination(for: URL.self) { urls, _ in
            if let url = urls.first { load(url) }
        }
    }

    private var addTitle: String {
        selected.count <= 1 ? "Add command" : "Add \(selected.count) commands"
    }

    private func binding(for name: String) -> Binding<Bool> {
        Binding {
            selected.contains(name)
        } set: { on in
            if on { selected.insert(name) } else { selected.remove(name) }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url)
    }

    private func load(_ url: URL) {
        folder = url
        project = ProjectDetector.detect(folder: url)
        let preferred = project?.scripts.first { $0.name == "dev" } ?? project?.scripts.first { $0.name == "start" }
        selected = Set(preferred.map { [$0.name] } ?? [])
    }

    private func add() {
        guard let project else { return }
        let specs = ProjectDetector.makeSpecs(for: project, selecting: Array(selected), group: nil)
        model.add(specs, newGroupNamed: makeGroup && specs.count > 1 ? project.name : nil)
        model.windowSelection = specs.first?.id
        close()
    }

    private func close() {
        model.editorRequest = nil
        dismiss()
    }
}
