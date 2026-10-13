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
        VStack(alignment: .leading, spacing: 16) {
            Text("Add from Project Folder")
                .font(.headline)
            if let project {
                scriptList(project)
            } else if let folder {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No package.json in “\(folder.lastPathComponent)”. Choose another folder, or add the command by hand.")
                    HStack {
                        Button("Choose Folder…") { chooseFolder() }
                        Button("Add Command…") { model.editorRequest = .new }
                    }
                }
            } else {
                dropZone
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { close() }
                    .keyboardShortcut(.cancelAction)
                Button(addTitle) { add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(project == nil || selected.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 540)
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Text("Drop a project folder here, or choose one that contains a package.json.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Choose Folder…") { chooseFolder() }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(.fill.quaternary, in: .rect(cornerRadius: 10, style: .continuous))
        .dropDestination(for: URL.self) { urls, _ in
            if let url = urls.first { load(url) }
        }
    }

    private func scriptList(_ project: DetectedProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(project.name).fontWeight(.semibold)
                Text(project.packageManager).foregroundStyle(.secondary)
                Spacer()
                Button("Choose Another…") { chooseFolder() }
            }
            List(project.scripts) { script in
                Toggle(isOn: binding(for: script.name)) {
                    HStack {
                        Text(script.name)
                        Text(script.body)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        if let port = script.port {
                            Text(verbatim: ":\(port)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .frame(height: 220)
            Toggle("Put them in a new group named “\(project.name)”", isOn: $makeGroup)
                .disabled(selected.count < 2)
        }
    }

    private var addTitle: String {
        selected.count <= 1 ? "Add Command" : "Add \(selected.count) Commands"
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
