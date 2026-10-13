import AmpersandCore
import SwiftUI

/// The selected row's live log tail, notices and actions (spec 4.2).
struct ExpandedRow: View {
    let runtime: CommandRuntime
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            notices
            logTail
            actions
        }
        .controlSize(.small)
        .padding(.leading, 32)   // aligns with the name: row padding + glyph + spacing
        .padding(.trailing, 8)
    }

    @ViewBuilder
    private var notices: some View {
        if let owner = runtime.portConflict {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "Port \(runtime.spec.port ?? 0) is in use by \(owner.name) (pid \(owner.pid)).")
                HStack {
                    Button("Start anyway") { model.start(runtime.id, force: true) }
                    Button(String("Kill pid \(owner.pid)")) { model.killPortOwnerAndStart(runtime.id) }
                }
            }
        }
        if case .failedToStart(let failure) = runtime.status {
            HStack {
                Text(failureText(failure))
                Button("Edit…") { model.requestEdit(runtime.id) }
            }
        }
        if runtime.needsRestartToApply {
            HStack {
                Text("Settings changed.")
                Button("Restart to apply") { model.restart(runtime.id) }
            }
        }
        if let since = runtime.healthFailingSince, case .unhealthy(let reason)? = runtime.health {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("Health check failing for \(StatusText.uptime(context.date.timeIntervalSince(since))): \(reason)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var logTail: some View {
        let lines = runtime.recentLines
        if lines.isEmpty {
            Text("No output yet.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(plain(line))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .textSelection(.enabled)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if runtime.portConflict == nil {   // the conflict notice offers its own start buttons
                Button(primaryTitle) { model.toggle(runtime.id) }
                    .buttonStyle(.borderedProminent)
                    .help("Return")
            }
            Button("Restart") { model.restart(runtime.id) }
                .disabled(!runtime.status.isActive)
                .help("⌘R")
            Button("Show log") { model.showLog(runtime.id) }
                .help("⌘L")
            if runtime.spec.port != nil {
                Button("Open in browser") { model.openInBrowser(runtime.id) }
                    .help("⌘O")
            }
        }
    }

    private var primaryTitle: String {
        if runtime.status.isActive { return "Stop" }
        return runtime.status.kind == .gaveUp ? "Start again" : "Start"
    }

    private func failureText(_ failure: StartFailure) -> String {
        switch failure {
        case .folderMissing(let path): "Folder not found: \(path)"
        case .envFileUnreadable(let path): "Can’t read the env file at \(path)."
        case .spawnFailed(let message): "Couldn’t start: \(message)"
        }
    }

    private func plain(_ line: String) -> String {
        var parser = ANSIParser()
        return parser.parse(line).map(\.text).joined()
    }
}
