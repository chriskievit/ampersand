import AmpersandCore
import SwiftUI

struct CommandRow: View {
    let runtime: CommandRuntime
    let model: AppModel
    let isSelected: Bool

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                StatusGlyph(kind: runtime.status.kind, healthFailing: runtime.healthFailingSince != nil)
                Text(runtime.spec.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let port = runtime.spec.port {
                    Text(verbatim: ":\(port)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    trailing(now: context.date)
                }
                // Always laid out, only shown on hover, so the metrics never shift (spec 4.6).
                Button {
                    model.toggle(runtime.id)
                } label: {
                    Image(systemName: runtime.status.isActive ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderless)
                .help(runtime.status.isActive ? "Stop" : "Start")
                .accessibilityLabel(runtime.status.isActive ? "Stop" : "Start")
                .opacity(hovering && !isSelected ? 1 : 0)
                .allowsHitTesting(hovering && !isSelected)
                .accessibilityHidden(!(hovering && !isSelected))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.selection)
                }
            }
            .environment(\.backgroundProminence, isSelected ? .increased : .standard)
            if isSelected {
                ExpandedRow(runtime: runtime, model: model)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, isSelected ? 6 : 0)
        .contentShape(.rect)
        .onTapGesture { model.popoverSelection = isSelected ? nil : runtime.id }
        .onHover { hovering = $0 }
        .help("\(runtime.spec.name)\n\(runtime.spec.command)")
        .contextMenu { CommandContextMenu(runtime: runtime, model: model) }
        .accessibilityElement(children: isSelected ? .contain : .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: runtime.status.isActive ? "Stop" : "Start") { model.toggle(runtime.id) }
        .accessibilityAction(named: "Restart") { model.restart(runtime.id) }
        .accessibilityAction(named: "Show log") { model.showLog(runtime.id) }
    }

    @ViewBuilder
    private func trailing(now: Date) -> some View {
        if let owner = runtime.portConflict, let port = runtime.spec.port, !isSelected {
            Text(verbatim: "port \(port) in use by \(owner.name)")
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if let stamp = StatusText.stamp(for: runtime.status, now: now) {
            Text(stamp)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        } else if let since = runtime.status.since {
            HStack(spacing: 10) {
                if let sample = runtime.sample {
                    Text(StatusText.cpu(sample.cpuPercent))
                    Text(StatusText.memory(sample.residentBytes))
                }
                Text(StatusText.uptime(now.timeIntervalSince(since)))
            }
            .foregroundStyle(.secondary)
            .monospacedDigit()
        } else {
            Text(StatusText.stateWord(runtime.status.kind))
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilityText: String {
        var parts = [runtime.spec.name, StatusText.stateWord(runtime.status.kind)]
        if let port = runtime.spec.port { parts.append("port \(port)") }
        if let sample = runtime.sample {
            parts.append("\(StatusText.cpu(sample.cpuPercent)) CPU")
            parts.append(StatusText.memory(sample.residentBytes))
        }
        if let since = runtime.status.since { parts.append("up \(StatusText.uptime(Date().timeIntervalSince(since)))") }
        if let stamp = StatusText.stamp(for: runtime.status, now: Date()) { parts.append(stamp) }
        return parts.joined(separator: ", ")
    }
}
