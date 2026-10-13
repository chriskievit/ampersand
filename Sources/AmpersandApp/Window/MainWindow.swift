import AmpersandCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MainWindow: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            if let runtime = model.runtime(model.windowSelection) {
                CommandDetail(runtime: runtime, model: model)
            } else {
                ContentUnavailableView("No Command Selected", systemImage: "terminal",
                                       description: Text("Select a command, or add one with ⌘N."))
            }
        }
        .frame(minWidth: 760, minHeight: 460)
        .sheet(item: $model.editorRequest) { request in
            switch request {
            case .new: CommandEditorSheet(model: model, original: nil)
            case .edit(let id): CommandEditorSheet(model: model, original: model.runtime(id)?.spec)
            case .importProject: ProjectImportSheet(model: model)
            }
        }
        .background(WindowVisibilityReader { model.isWindowVisible = $0 })
        .onAppear {
            ActivationPolicyController.windowDidAppear()
            if model.windowSelection == nil { model.windowSelection = model.orderedRuntimes.first?.id }
        }
        .onDisappear {
            model.isWindowVisible = false
            ActivationPolicyController.windowDidDisappear()
        }
    }
}

private struct CommandDetail: View {
    let runtime: CommandRuntime
    @Bindable var model: AppModel
    @State private var follow = true

    var body: some View {
        Group {
            switch model.windowTab {
            case .log: logPane
            case .settings: settingsPane(for: runtime)
            }
        }
        .navigationTitle(runtime.spec.name)
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $model.windowTab) {
                    Text("Log").tag(DetailTab.log)
                    Text("Settings").tag(DetailTab.settings)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ToolbarItemGroup {
                Button(runtime.status.isActive ? "Stop" : "Start",
                       systemImage: runtime.status.isActive ? "stop.fill" : "play.fill") { model.toggle(runtime.id) }
                Button("Restart", systemImage: "arrow.clockwise") { model.restart(runtime.id) }
                    .disabled(!runtime.status.isActive)
                if runtime.spec.port != nil {
                    Button("Open in Browser", systemImage: "safari") { model.openInBrowser(runtime.id) }
                }
            }
        }
    }

    private var subtitle: String {
        StatusText.stamp(for: runtime.status, now: Date()) ?? StatusText.stateWord(runtime.status.kind)
    }

    private var logPane: some View {
        LogView(runtime: runtime, totalCommitted: runtime.totalCommitted, partialLine: runtime.partialLine,
                generation: runtime.logGeneration, follow: $follow)
            .overlay(alignment: .bottomTrailing) {
                if !follow {
                    Button("Jump to Latest", systemImage: "arrow.down") { follow = true }
                        .padding()
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button("Clear", systemImage: "trash") { model.clearLog(runtime.id) }
                    Button("Copy All", systemImage: "doc.on.doc") { copyAll() }
                    Button("Export…", systemImage: "square.and.arrow.up") { export() }
                }
            }
    }

    @ViewBuilder
    private func settingsPane(for runtime: CommandRuntime) -> some View {
        CommandSettingsPane(runtime: runtime, model: model)
            .id(runtime.id)
    }

    private var plainLog: String {
        (runtime.lines + (runtime.partialLine.isEmpty ? [] : [runtime.partialLine]))
            .map { line in
                var parser = ANSIParser()
                return parser.parse(line).map(\.text).joined()
            }
            .joined(separator: "\n")
    }

    private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plainLog, forType: .string)
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(runtime.spec.name).log"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try plainLog.write(to: url, atomically: true, encoding: .utf8) }
        catch { model.show(Banner(message: "Couldn’t export the log: \(error.localizedDescription)")) }
    }
}
