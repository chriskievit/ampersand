#if DEBUG
import AmpersandCore
import SwiftUI

@MainActor
private func previewRuntime(_ name: String, _ status: CommandStatus, port: Int? = nil,
                            sample: ResourceSample? = nil, healthFailing: Bool = false,
                            lines: [String] = []) -> CommandRuntime {
    let spec = CommandSpec(name: name, command: "npm run dev", port: port)
    let runtime = CommandRuntime(spec: spec, supervisor: Supervisor(spec: spec))
    runtime.status = status
    runtime.sample = sample
    if healthFailing {
        runtime.health = .unhealthy("HTTP 502")
        runtime.healthFailingSince = Date().addingTimeInterval(-30)
    }
    if !lines.isEmpty { runtime.receive(newLines: lines, partialLine: "") }
    return runtime
}

@MainActor
private let previewModel = AppModel(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ampersand-preview"))

#Preview("Row states") {
    let now = Date()
    let sample = ResourceSample(cpuPercent: 3.2, residentBytes: 88_000_000)
    VStack(alignment: .leading, spacing: 2) {
        CommandRow(runtime: previewRuntime("api", .running(since: now - 8040), port: 8080, sample: sample), model: previewModel, isSelected: false)
        CommandRow(runtime: previewRuntime("web", .running(since: now - 2460), port: 3000, sample: sample,
                                           lines: ["VITE v6 ready in 412 ms", "➜  Local: http://localhost:3000/"]),
                   model: previewModel, isSelected: true)
        CommandRow(runtime: previewRuntime("storybook", .starting(since: now)), model: previewModel, isSelected: false)
        CommandRow(runtime: previewRuntime("worker", .backoff(exit: .exited(1), at: now, restartAt: now + 4)), model: previewModel, isSelected: false)
        CommandRow(runtime: previewRuntime("queue", .exited(.signaled(9), at: now)), model: previewModel, isSelected: false)
        CommandRow(runtime: previewRuntime("db", .gaveUp(exit: .exited(1), at: now)), model: previewModel, isSelected: false)
        CommandRow(runtime: previewRuntime("docs", .failedToStart(.folderMissing("~/dev/docs"))), model: previewModel, isSelected: false)
        CommandRow(runtime: previewRuntime("health", .running(since: now - 600), port: 4000, sample: sample, healthFailing: true), model: previewModel, isSelected: false)
        CommandRow(runtime: previewRuntime("caffeinate", .stopped), model: previewModel, isSelected: false)
    }
    .padding(8)
    .frame(width: 360)
}

#Preview("Empty state") {
    EmptyStateView(model: previewModel)
        .frame(width: 360)
}
#endif
