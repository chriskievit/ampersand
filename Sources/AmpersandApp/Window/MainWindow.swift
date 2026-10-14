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
            Group {
                if let runtime = model.runtime(model.windowSelection) {
                    CommandDetail(runtime: runtime, model: model)
                } else {
                    ContentUnavailableView("No command selected", systemImage: "terminal",
                                           description: Text("Select a command, or add one with ⌘N."))
                }
            }
            // Notices belong to the detail pane, on the bar material, never over the sidebar.
            .safeAreaInset(edge: .top, spacing: 0) { WindowNotices(model: model) }
        }
        .frame(minWidth: 760, minHeight: 460)
        .sheet(item: $model.editorRequest) { request in
            switch request {
            case .new(let prefill): CommandEditorSheet(model: model, original: nil, prefill: prefill)
            case .edit(let id): CommandEditorSheet(model: model, original: model.runtime(id)?.spec)
            case .importProject: ProjectImportSheet(model: model)
            }
        }
        .alert(model.restartPromptText.title, isPresented: Binding(
            get: { model.restartPrompt != nil },
            set: { if !$0 { model.answerRestartPrompt(restartNow: false) } })) {
            Button("Restart now") { model.answerRestartPrompt(restartNow: true) }
            Button("Later", role: .cancel) { model.answerRestartPrompt(restartNow: false) }
        } message: {
            Text(model.restartPromptText.message)
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
                Menu {
                    Button("Open in browser") { model.openInBrowser(runtime.id) }
                        .disabled(runtime.spec.port == nil)
                    Divider()
                    Button("Clear log") { model.clearLog(runtime.id) }
                    Button("Copy log") { model.copyLog(runtime.id) }
                    Button("Export log…") { model.exportLog(runtime.id) }
                } label: {
                    Label { Text(verbatim: "More") } icon: { Image(systemName: "ellipsis.circle") }
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
            .overlay {
                if runtime.lines.isEmpty && runtime.partialLine.isEmpty {
                    ContentUnavailableView("No output", systemImage: "text.alignleft",
                                           description: Text(runtime.status.isActive
                                                             ? "Waiting for the command to print something."
                                                             : "Start the command to see its output."))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !follow {
                    Button("Jump to latest", systemImage: "arrow.down") { follow = true }
                        .padding()
                }
            }
    }

    @ViewBuilder
    private func settingsPane(for runtime: CommandRuntime) -> some View {
        CommandSettingsPane(runtime: runtime, model: model)
            .id(runtime.id)
    }
}

/// Feedback the window must show itself: banners (save, import and export errors) and a
/// start blocked by a port conflict, as native grouped boxes above the content.
private struct WindowNotices: View {
    let model: AppModel

    var body: some View {
        let conflict = model.runtime(model.windowSelection).flatMap { runtime in
            runtime.portConflict.map { (runtime, $0) }
        }
        if model.banner != nil || conflict != nil {
            VStack(spacing: 8) {
                if let banner = model.banner {
                    GroupBox {
                        LabeledContent {
                            HStack {
                                switch banner.action {
                                case .retrySave: Button("Retry") { model.retrySave() }
                                case .revealConfig: Button("Show in Finder") { model.revealConfig() }
                                case nil: EmptyView()
                                }
                                Button("Dismiss") { model.banner = nil }
                            }
                            .fixedSize()   // buttons keep their size; the message wraps
                        } label: {
                            Label(banner.message, systemImage: banner.isProblem ? "exclamationmark.triangle" : "info.circle")
                        }
                    }
                }
                if let (runtime, owner) = conflict {
                    GroupBox {
                        LabeledContent {
                            HStack {
                                Button("Start anyway") { model.start(runtime.id, force: true) }
                                Button(String("Kill pid \(owner.pid)")) { model.killPortOwnerAndStart(runtime.id) }
                            }
                            .fixedSize()
                        } label: {
                            Label {
                                Text(verbatim: "Port \(runtime.spec.port ?? 0) is in use by \(owner.name) (pid \(owner.pid)).")
                            } icon: {
                                Image(systemName: "exclamationmark.triangle")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }
}
