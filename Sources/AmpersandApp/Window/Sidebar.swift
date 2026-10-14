import AmpersandCore
import SwiftUI

struct Sidebar: View {
    @Bindable var model: AppModel
    @State private var renamingGroup: String?
    @State private var groupName = ""
    @State private var query = ""
    @State private var revealGroup: String?
    @FocusState private var renameFocused: Bool
    @State private var dropTargetGroup: String?
    @State private var editingGroup: GroupSpec?

    var body: some View {
        ScrollViewReader { proxy in
            list
                .onChange(of: revealGroup) { _, id in
                    guard let id else { return }
                    withAnimation(.snappy) { proxy.scrollTo(headerID(id)) }
                    revealGroup = nil
                }
        }
        .newGroupAlert(isPresented: $model.isAddingGroup) { name in
            query = ""   // a filter would hide the new, empty group
            revealGroup = model.addGroup(named: name).id
        }
    }

    private var list: some View {
        List(selection: $model.windowSelection) {
            ForEach(visibleSections) { section in
                Section {
                    ForEach(section.commands) { spec in
                        if let runtime = model.runtime(spec.id) {
                            row(runtime).tag(spec.id)
                        }
                    }
                    // Drops between rows, from this group or another, with the list's own insertion line.
                    .dropDestination(for: String.self) { items, index in
                        guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return }
                        // The index counts visible rows; anchor to a row so a search filter can't skew it.
                        let visible = section.commands.map(\.id)
                        let placing: ConfigEditor.Placement = index < visible.count
                            ? .before(visible[index])
                            : visible.last.map { .after($0) } ?? .end
                        drop(id, into: section, placing: placing)
                    }
                } header: {
                    if section.group != nil || !model.config.groups.isEmpty {
                        header(for: section)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // Drawn outside the text's frame, so the header does not move.
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.2))
                                    .padding(.horizontal, -6)
                                    .padding(.vertical, -2)
                                    .opacity(dropTargetGroup == section.id ? 1 : 0)
                            }
                            // A drop on the header (or on an empty group) goes to the end of the group.
                            .dropDestination(for: String.self) { items, _ in
                                guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                                return drop(id, into: section, placing: .end)
                            } isTargeted: { targeted in
                                if targeted {
                                    dropTargetGroup = section.id
                                } else if dropTargetGroup == section.id {
                                    dropTargetGroup = nil
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .sheet(item: $editingGroup) { group in GroupSettingsSheet(model: model, group: group) }
        .searchable(text: $query, placement: .sidebar, prompt: "Search")
        .onDeleteCommand {
            if let id = model.windowSelection { model.delete(id) }
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("New command…") { model.requestNew() }
                    Button("Add from project folder…") { model.requestImport() }
                    Divider()
                    Button("New group…") { model.requestNewGroup() }
                } label: {
                    // Verbatim: SwiftUI would otherwise pick up the system's translation of "Add".
                    Label { Text(verbatim: "Add") } icon: { Image(systemName: "plus") }
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
        .itemProvider { NSItemProvider(object: runtime.id.uuidString as NSString) }
        .contextMenu { CommandContextMenu(runtime: runtime, model: model) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(runtime.spec.name), \(StatusText.stateWord(runtime.status.kind))")
    }

    @ViewBuilder
    private func header(for section: ConfigSection) -> some View {
        if let group = section.group {
            Group {
                if renamingGroup == group.id {
                    TextField("Group name", text: $groupName)
                        .focused($renameFocused)
                        .onSubmit { commitRename(group.id) }
                        .onExitCommand { renamingGroup = nil }
                        .onAppear { renameFocused = true }
                        // Clicking elsewhere keeps the typed name, as a Finder rename does.
                        .onChange(of: renameFocused) { _, focused in
                            if !focused { commitRename(group.id) }
                        }
                } else {
                    Text(group.name)
                        .onTapGesture(count: 2) { beginRename(group) }
                        .contextMenu {
                            Button("Start all") { model.commands(inGroup: group.id).forEach { model.start($0.id) } }
                            Button("Stop all") { model.commands(inGroup: group.id).forEach { model.stop($0.id) } }
                            Divider()
                            Button("Rename…") { beginRename(group) }
                            Button("Group settings…") { editingGroup = group }
                            Button("Delete group", role: .destructive) { model.deleteGroup(group.id) }
                        }
                }
            }
            .id(headerID(group.id))
        } else if !model.config.groups.isEmpty {
            Text("No group")
        }
    }

    private func headerID(_ groupID: String) -> String { "group-header-\(groupID)" }

    private func beginRename(_ group: GroupSpec) {
        groupName = group.name
        renamingGroup = group.id
    }

    private func commitRename(_ groupID: String) {
        guard renamingGroup == groupID else { return }
        model.renameGroup(groupID, to: groupName)
        renamingGroup = nil
    }

    /// Every drag in the sidebar ends here: between rows or on a group header. Same-group drops
    /// reorder; drops on another group also move the command into it, and offer a restart
    /// when that changes its working directory.
    @discardableResult
    private func drop(_ id: UUID, into section: ConfigSection, placing: ConfigEditor.Placement) -> Bool {
        guard model.runtime(id) != nil else { return false }
        model.move(id, toGroup: section.group?.id, placing: placing)
        return true
    }
}
