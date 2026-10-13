import AmpersandCore
import SwiftUI

struct Sidebar: View {
    @Bindable var model: AppModel
    @State private var renamingGroup: String?
    @State private var groupName = ""
    @State private var query = ""

    var body: some View {
        List(selection: $model.windowSelection) {
            ForEach(visibleSections) { section in
                Section {
                    ForEach(section.commands) { spec in
                        if let runtime = model.runtime(spec.id) {
                            row(runtime).tag(spec.id)
                        }
                    }
                    .onMove { offsets, destination in
                        move(in: section, from: offsets, to: destination)
                    }
                } header: {
                    header(for: section)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $query, placement: .sidebar, prompt: "Search")
        .onDeleteCommand {
            if let id = model.windowSelection { model.delete(id) }
        }
        .toolbar {
            ToolbarItem {
                Menu("Add", systemImage: "plus") {
                    Button("New Command…") { model.requestNew() }
                    Button("Add from Project Folder…") { model.requestImport() }
                    Divider()
                    Button("New Group") {
                        let group = model.addGroup(named: "")
                        groupName = group.name
                        renamingGroup = group.id
                    }
                }
            }
        }
    }

    /// Sections filtered by the search field (name or command line).
    private var visibleSections: [ConfigSection] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return model.sections }
        return model.sections.compactMap { section in
            var filtered = section
            filtered.commands = section.commands.filter {
                $0.name.localizedCaseInsensitiveContains(q) || $0.command.localizedCaseInsensitiveContains(q)
            }
            return filtered.commands.isEmpty ? nil : filtered
        }
    }

    private func row(_ runtime: CommandRuntime) -> some View {
        LabeledContent {
            if let port = runtime.spec.port {
                Text(verbatim: ":\(port)").monospacedDigit()
            }
        } label: {
            Label {
                Text(runtime.spec.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                StatusGlyph(kind: runtime.status.kind, healthFailing: runtime.healthFailingSince != nil)
            }
        }
        .help(runtime.spec.command)
        .contextMenu { CommandContextMenu(runtime: runtime, model: model) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(runtime.spec.name), \(StatusText.stateWord(runtime.status.kind))")
    }

    @ViewBuilder
    private func header(for section: ConfigSection) -> some View {
        if let group = section.group {
            if renamingGroup == group.id {
                TextField("Group Name", text: $groupName)
                    .onSubmit {
                        model.renameGroup(group.id, to: groupName)
                        renamingGroup = nil
                    }
                    .onExitCommand { renamingGroup = nil }
            } else {
                Text(group.name)
                    .onTapGesture(count: 2) {
                        groupName = group.name
                        renamingGroup = group.id
                    }
                    .contextMenu {
                        Button("Start All") { model.commands(inGroup: group.id).forEach { model.start($0.id) } }
                        Button("Stop All") { model.commands(inGroup: group.id).forEach { model.stop($0.id) } }
                        Divider()
                        Button("Rename…") {
                            groupName = group.name
                            renamingGroup = group.id
                        }
                        Button("Delete Group", role: .destructive) { model.deleteGroup(group.id) }
                    }
            }
        } else if !model.config.groups.isEmpty {
            Text("No Group")
        }
    }

    /// Native list reordering within a section; moving between groups is in the context menu.
    private func move(in section: ConfigSection, from offsets: IndexSet, to destination: Int) {
        guard let source = offsets.first else { return }
        let ids = section.commands.map(\.id)
        let id = ids[source]
        if destination < ids.count {
            if ids[destination] != id { model.reorder(id, before: ids[destination]) }
        } else if let last = ids.last, last != id {
            // Past the end of this group: place it right after the group's last command.
            let all = model.config.commands.map(\.id)
            if let lastIndex = all.firstIndex(of: last), lastIndex + 1 < all.count {
                model.reorder(id, before: all[lastIndex + 1])
            } else {
                model.reorder(id, before: nil)
            }
        }
    }
}
