import AmpersandCore
import SwiftUI

struct Sidebar: View {
    @Bindable var model: AppModel
    @State private var renamingGroup: String?
    @State private var groupName = ""

    var body: some View {
        List(selection: $model.windowSelection) {
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.commands) { spec in
                        if let runtime = model.runtime(spec.id) {
                            row(runtime)
                                .tag(spec.id)
                                .draggable(spec.id.uuidString)
                                .dropDestination(for: String.self) { items, _ in
                                    drop(items, before: spec.id, group: section.group?.id)
                                }
                        }
                    }
                } header: {
                    header(for: section)
                        .dropDestination(for: String.self) { items, _ in
                            drop(items, before: nil, group: section.group?.id)
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Menu {
                    Button("New Command…") { model.requestNew() }
                    Button("Add from Project Folder…") { model.requestImport() }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                Button("New Group") {
                    let group = model.addGroup(named: "")
                    groupName = group.name
                    renamingGroup = group.id
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
        }
    }

    private func row(_ runtime: CommandRuntime) -> some View {
        HStack(spacing: 6) {
            StatusGlyph(kind: runtime.status.kind, healthFailing: runtime.healthFailingSince != nil)
            Text(runtime.spec.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let port = runtime.spec.port {
                Text(verbatim: ":\(port)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
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

    /// Dropping a row onto another row moves it before that row and into that row's group.
    @discardableResult
    private func drop(_ items: [String], before target: UUID?, group: String?) -> Bool {
        guard let raw = items.first, let id = UUID(uuidString: raw), id != target else { return false }
        if model.runtime(id)?.spec.group != group { model.move(id, toGroup: group) }
        model.reorder(id, before: target)
        return true
    }
}
