import AmpersandCore
import Foundation
import Observation

/// Live UI state for one command, fed by its Supervisor's events.
@MainActor @Observable
final class CommandRuntime: Identifiable {
    static let logCapacity = 10_000

    let id: UUID
    let supervisor: Supervisor
    var spec: CommandSpec
    var status: CommandStatus = .stopped
    var pid: pid_t?
    var sample: ResourceSample?
    var health: HealthResult?
    var healthFailingSince: Date?
    var portConflict: PortOwner?
    var needsRestartToApply = false

    private(set) var lines: [String] = []
    private(set) var partialLine = ""
    /// Monotonic count of committed lines, so the log view can append only what is new.
    private(set) var totalCommitted = 0
    /// Bumped when the log is cleared, so the log view re-renders from scratch.
    private(set) var logGeneration = 0

    @ObservationIgnored private var pendingLines: [String] = []
    @ObservationIgnored private var pendingPartial: String?
    @ObservationIgnored private var flushScheduled = false

    init(spec: CommandSpec, supervisor: Supervisor) {
        self.id = spec.id
        self.spec = spec
        self.supervisor = supervisor
    }

    /// The last five non-blank lines, for the popover's log tail.
    var recentLines: [String] {
        let blank: (String) -> Bool = { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        var tail = Array(lines.lazy.reversed().filter { !blank($0) }.prefix(blank(partialLine) ? 5 : 4).reversed())
        if !blank(partialLine) { tail.append(partialLine) }
        return tail
    }

    /// Coalesces output into one UI update every ~50 ms.
    func receive(newLines: [String], partialLine: String) {
        pendingLines += newLines
        pendingPartial = partialLine
        guard !flushScheduled else { return }
        flushScheduled = true
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            flush()
        }
    }

    func clearLog() {
        lines = []
        partialLine = ""
        pendingLines = []
        pendingPartial = nil
        logGeneration += 1
    }

    private func flush() {
        flushScheduled = false
        if !pendingLines.isEmpty {
            lines += pendingLines
            totalCommitted += pendingLines.count
            pendingLines.removeAll()
            if lines.count > Self.logCapacity { lines.removeFirst(lines.count - Self.logCapacity) }
        }
        if let partial = pendingPartial {
            partialLine = partial
            pendingPartial = nil
        }
    }
}
