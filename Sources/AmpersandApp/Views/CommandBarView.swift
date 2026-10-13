import AmpersandCore
import AppKit
import SwiftUI

/// The popover: a Spotlight-style command bar (direction contract: Command Bar).
struct CommandBarView: View {
    @Bindable var model: AppModel
    @State private var filter = ""
    @State private var rowsHeight: CGFloat = 0
    @FocusState private var filterFocused: Bool
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            if let banner = model.banner {
                InlineBanner(banner: banner, model: model)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 360)
        // Keys keep working after Tab moves focus off the filter field.
        .onKeyPress(phases: .down, action: handleKey)
        // Reduce Motion: a short crossfade instead of the spring, never a snap.
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy, value: model.popoverSelection)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy, value: model.banner)
        .background(WindowVisibilityReader { visible in
            model.isPopoverVisible = visible
            if visible {
                filter = ""
                filterFocused = true
                selectInitialRow()
            }
        })
        .onChange(of: filter) { _, query in
            // Typing narrows the list; keep a match selected so Return acts on it.
            if !query.isEmpty { model.popoverSelection = visibleRuntimes.first?.id }
        }
    }

    /// The contract's first viewport: open on the row that needs attention, else where you were.
    private func selectInitialRow() {
        let visible = visibleRuntimes
        if let attention = visible.first(where: {
            [.exited, .gaveUp, .failed].contains($0.status.kind) || $0.portConflict != nil
        }) {
            model.popoverSelection = attention.id
        } else if let current = model.popoverSelection, visible.contains(where: { $0.id == current }) {
            return
        } else {
            model.popoverSelection = visible.first?.id
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter Commands", text: $filter)
                .textFieldStyle(.plain)
                // A filter needs no system suggestions; their (empty) panel covered the list.
                .autocorrectionDisabled()
                .textContentType(nil)
                .writingToolsBehavior(.disabled)
                .focused($filterFocused)
                .onKeyPress(phases: .down, action: handleKey)
            Text("\(model.runningCount) running")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(12)
    }

    // MARK: Content

    private struct VisibleSection: Identifiable {
        var section: ConfigSection
        var runtimes: [CommandRuntime]
        var id: String { section.id }
    }

    private var visibleSections: [VisibleSection] {
        let query = filter.trimmingCharacters(in: .whitespaces)
        return model.sections.compactMap { section in
            let runtimes = section.commands.compactMap { model.runtime($0.id) }.filter { runtime in
                query.isEmpty
                    || runtime.spec.name.localizedCaseInsensitiveContains(query)
                    || runtime.spec.command.localizedCaseInsensitiveContains(query)
            }
            return runtimes.isEmpty ? nil : VisibleSection(section: section, runtimes: runtimes)
        }
    }

    private var visibleRuntimes: [CommandRuntime] { visibleSections.flatMap(\.runtimes) }

    @ViewBuilder
    private var content: some View {
        if model.config.commands.isEmpty {
            EmptyStateView(model: model)
        } else if visibleRuntimes.isEmpty {
            VStack(spacing: 8) {
                Text("No commands match “\(filter)”")
                    .foregroundStyle(.secondary)
                Button("Clear") { filter = "" }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        } else {
            ScrollViewReader { proxy in
                // A MenuBarExtra window sizes to its content's ideal height, and a ScrollView's ideal
                // height is zero there, so size the scroll view to the measured rows (max 480 pt).
                ScrollView {
                    rows.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsHeight = $0 }
                }
                .frame(height: min(max(rowsHeight, 1), 480))
                .onChange(of: model.popoverSelection) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(visibleSections) { entry in
                if let group = entry.section.group {
                    GroupHeader(group: group, model: model)
                } else if !model.config.groups.isEmpty {
                    Text("No Group")
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(entry.runtimes) { runtime in
                    CommandRow(runtime: runtime, model: model, isSelected: runtime.id == model.popoverSelection)
                        .id(runtime.id)
                }
            }
        }
        .padding(8)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Menu {
                Button("Add Command…") { model.requestNew() }
                Button("Add from Project Folder…") { model.requestImport() }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            Spacer()
            Button("Open Ampersand") { model.openMainWindow() }
                .buttonStyle(.borderless)
                .lineLimit(1)
            // The longest label that fits: "Quit and Stop 3 Processes" → "Quit and Stop 3" → "Quit".
            ViewThatFits(in: .horizontal) {
                ForEach(quitTitles, id: \.self) { title in
                    Button(title) { NSApp.terminate(nil) }
                        .help(quitTitles[0])
                        .buttonStyle(.borderless)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .foregroundStyle(.primary)   // one treatment for all three footer controls
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var quitTitles: [String] {
        let count = model.processCount
        guard count > 0 else { return ["Quit"] }
        return ["Quit and Stop \(count) \(count == 1 ? "Process" : "Processes")", "Quit and Stop \(count)", "Quit"]
    }

    // MARK: Keyboard (spec 4.2)

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let selected = model.popoverSelection.flatMap { id in visibleRuntimes.first { $0.id == id } }
        if press.key == .upArrow { moveSelection(-1); return .handled }
        if press.key == .downArrow { moveSelection(1); return .handled }
        if press.key == .return {
            guard let selected else { return .ignored }
            if press.modifiers.contains(.option) { model.toggleGroup(selected.spec.group) } else { model.toggle(selected.id) }
            return .handled
        }
        if press.key == .escape {
            guard !filter.isEmpty else { return .ignored }   // lets the popover close
            filter = ""
            return .handled
        }
        guard press.modifiers.contains(.command) else { return .ignored }
        switch press.characters.lowercased() {
        case "n": model.requestNew()
        case ",": openSettings(); NSApp.activate()
        case "r": if let selected { model.restart(selected.id) } else { return .ignored }
        case "l": if let selected { model.showLog(selected.id) } else { return .ignored }
        case "o": if let selected { model.openInBrowser(selected.id) } else { return .ignored }
        case "d": if let selected { model.duplicate(selected.id) } else { return .ignored }
        case let digit where digit.count == 1 && ("1"..."9").contains(digit):
            let index = Int(digit)! - 1
            guard index < visibleRuntimes.count else { return .ignored }
            model.popoverSelection = visibleRuntimes[index].id
        case "z":
            guard model.undoManager.canUndo else { return .ignored }
            model.undoManager.undo()
        default:
            return .ignored
        }
        return .handled
    }

    private func moveSelection(_ delta: Int) {
        let ids = visibleRuntimes.map(\.id)
        guard !ids.isEmpty else { return }
        guard let current = model.popoverSelection, let index = ids.firstIndex(of: current) else {
            model.popoverSelection = delta > 0 ? ids.first : ids.last
            return
        }
        model.popoverSelection = ids[min(max(index + delta, 0), ids.count - 1)]
    }
}

private struct GroupHeader: View {
    let group: GroupSpec
    let model: AppModel
    @State private var hovering = false

    private var anyActive: Bool { model.commands(inGroup: group.id).contains { $0.status.isActive } }

    var body: some View {
        HStack {
            Text(group.name)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if hovering {
                Button(anyActive ? "Stop All" : "Start All") { model.toggleGroup(group.id) }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .contentShape(.rect)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Start All") { model.commands(inGroup: group.id).forEach { model.start($0.id) } }
            Button("Stop All") { model.commands(inGroup: group.id).forEach { model.stop($0.id) } }
        }
    }
}
