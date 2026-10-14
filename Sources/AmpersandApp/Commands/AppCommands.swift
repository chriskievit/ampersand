import AmpersandCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The app's menus (spec 4.3). Command actions apply to the command selected in the window.
struct AppCommands: Commands {
    let model: AppModel

    private var selected: CommandRuntime? { model.runtime(model.windowSelection) }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New command") { model.requestNew() }
                .keyboardShortcut("n")
            Button("Add from project folder…") { model.requestImport() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Import…") { importConfig() }
            Button("Export…") { exportConfig() }
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { undo() }
                .keyboardShortcut("z")
            Button("Redo") { redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        TextEditingCommands()
        CommandMenu("Command") {
            Button(selected?.status.isActive == true ? "Stop" : "Start") {
                if let selected { model.toggle(selected.id) }
            }
            .keyboardShortcut(.return)
            .disabled(selected == nil)
            Button("Restart") {
                if let selected { model.restart(selected.id) }
            }
            .keyboardShortcut("r")
            .disabled(selected?.status.isActive != true)
            Button("Start/stop group") {
                if let selected { model.toggleGroup(selected.spec.group) }
            }
            .keyboardShortcut(.return, modifiers: [.command, .option])
            .disabled(selected == nil)
            Divider()
            Button("Show log") {
                if let selected { model.showLog(selected.id) }
            }
            .keyboardShortcut("l")
            .disabled(selected == nil)
            Button("Open in browser") {
                if let selected { model.openInBrowser(selected.id) }
            }
            .keyboardShortcut("o")
            .disabled(selected?.spec.port == nil)
            Divider()
            Button("Edit…") {
                if let selected { model.requestEdit(selected.id) }
            }
            .keyboardShortcut("e")
            .disabled(selected == nil)
            Button("Duplicate") {
                if let selected { model.duplicate(selected.id) }
            }
            .keyboardShortcut("d")
            .disabled(selected == nil)
            Menu("Move to group") {
                Button("No group") { if let selected { model.move(selected.id, toGroup: nil) } }
                Divider()
                ForEach(model.config.groups) { group in
                    Button(group.name) { if let selected { model.move(selected.id, toGroup: group.id) } }
                }
            }
            .disabled(selected == nil)
            Button("Move up") { if let selected { model.move(selected.id, by: -1) } }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled(selected == nil)
            Button("Move down") { if let selected { model.move(selected.id, by: 1) } }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(selected == nil)
            Button("New group…") { model.requestNewGroup() }
            Divider()
            // No ⌘⌫ here: a menu key equivalent would fire while editing text. The sidebar's
            // Edit ▸ Delete (onDeleteCommand) covers the keyboard path.
            Button("Delete") {
                if let selected { model.delete(selected.id) }
            }
            .disabled(selected == nil)
        }
        CommandMenu("Log") {
            Button("Clear log") { if let selected { model.clearLog(selected.id) } }
                .keyboardShortcut("k")
                .disabled(selected == nil)
            Button("Copy log") { if let selected { model.copyLog(selected.id) } }
                .disabled(selected == nil)
            Button("Export log…") { if let selected { model.exportLog(selected.id) } }
                .disabled(selected == nil)
        }
        CommandGroup(before: .toolbar) {
            Button("Show log") { model.windowTab = .log }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("Show command settings") { model.windowTab = .settings }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Divider()
        }
    }

    /// Text fields keep their own undo; everything else undoes config edits.
    private func undo() {
        if isEditingText { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
        else if model.undoManager.canUndo { model.undoManager.undo() }
    }

    private func redo() {
        if isEditingText { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
        else if model.undoManager.canRedo { model.undoManager.redo() }
    }

    private var isEditingText: Bool {
        (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Ampersand Commands.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.exportConfig(to: url)
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !model.config.commands.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Replace your \(model.config.commands.count) commands?"
            alert.informativeText = "Importing stops every running command and replaces your commands and groups with the ones in the file."
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        Task { await model.importConfig(from: url) }
    }
}
