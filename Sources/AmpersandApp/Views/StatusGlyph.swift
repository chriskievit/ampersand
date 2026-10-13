import AmpersandCore
import SwiftUI

extension CommandStatus {
    var since: Date? {
        switch self {
        case .starting(let since), .running(let since): since
        default: nil
        }
    }
}

/// State is carried by shape first; the system colour is secondary (spec 4.2).
struct StatusGlyph: View {
    let kind: CommandStatus.Kind
    let healthFailing: Bool

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(color)
            .overlay(alignment: .bottomTrailing) {
                if healthFailing && kind == .running {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .imageScale(.small)
                        .foregroundStyle(.yellow)
                        .offset(x: 4, y: 3)
                }
            }
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch kind {
        case .running: "circle.fill"
        case .starting, .stopping, .backoff: "circle.dashed"
        case .exited, .gaveUp, .failed: "xmark.octagon.fill"
        case .stopped: "circle"
        }
    }

    private var color: Color {
        switch kind {
        case .running: .green
        case .starting, .stopping, .backoff: .orange
        case .exited, .gaveUp, .failed: .red
        case .stopped: .secondary
        }
    }
}
