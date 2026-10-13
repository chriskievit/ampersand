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
        .safeAreaInset(edge: .top, spacing: 0) { WindowNotices(model: model) }
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
                    Button("Copy All", systemImage: "doc.on.doc") { model.copyLog(runtime.id) }
                    Button("Export…", systemImage: "square.and.arrow.up") { model.exportLog(runtime.id) }
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
/// start blocked by a port conflict (audit P1: these were visible only in the popover).
private struct WindowNotices: View {
    let model: AppModel

    var body: some View {
        let conflict = model.runtime(model.windowSelection).flatMap { runtime in
            runtime.portConflict.map { (runtime, $0) }
        }
        if model.banner != nil || conflict != nil {
            VStack(spacing: 8) {
                if let banner = model.banner {
                    InlineBanner(banner: banner, model: model)
                }
                if let (runtime, owner) = conflict {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Port \(runtime.spec.port ?? 0) is in use by \(owner.name) (pid \(owner.pid)).")
                        Spacer(minLength: 4)
                        Button("Start Anyway") { model.start(runtime.id, force: true) }
                        Button("Kill pid \(owner.pid)") { model.killPortOwnerAndStart(runtime.id) }
                    }
                    .controlSize(.small)
                    .padding(10)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
