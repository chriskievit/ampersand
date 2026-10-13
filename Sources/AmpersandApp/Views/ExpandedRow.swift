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
        .padding(.leading, 24)
    }

    @ViewBuilder
    private var notices: some View {
        if let owner = runtime.portConflict {
            VStack(alignment: .leading, spacing: 4) {
                Text("Port \(runtime.spec.port ?? 0) is in use by \(owner.name) (pid \(owner.pid)).")
                HStack {
                    Button("Start Anyway") { model.start(runtime.id, force: true) }
                    Button("Kill pid \(owner.pid)") { model.killPortOwnerAndStart(runtime.id) }
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
                Button("Restart to Apply") { model.restart(runtime.id) }
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
                .foregroundStyle(.tertiary)
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
            Button(primaryTitle) { model.toggle(runtime.id) }
                .help("Return")
            Button("Restart") { model.restart(runtime.id) }
                .disabled(!runtime.status.isActive)
                .help("⌘R")
            Button("Show Log") { model.showLog(runtime.id) }
                .help("⌘L")
            if runtime.spec.port != nil {
                Button("Open in Browser") { model.openInBrowser(runtime.id) }
                    .help("⌘O")
            }
        }
        .controlSize(.small)
    }

    private var primaryTitle: String {
        if runtime.status.isActive { return "Stop" }
        return runtime.status.kind == .gaveUp ? "Start Again" : "Start"
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
