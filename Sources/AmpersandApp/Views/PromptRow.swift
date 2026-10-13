import AmpersandCore
import SwiftUI

/// Shown when the filter matches nothing: the typed text, read as a command you can add.
/// Laid out like a selected, expanded row so Return reads as its primary action.
struct PromptRow: View {
    let spec: CommandSpec
    let add: () -> Void
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(verbatim: "&")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text(spec.command)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(nsColor: .selectedContentBackgroundColor)))
            .environment(\.backgroundProminence, .increased)

            VStack(alignment: .leading, spacing: 8) {
                Text(summary)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Add and start", action: add)
                        .buttonStyle(.borderedProminent)
                        .help("Return")
                    Button("Edit first…", action: edit)
                        .help("⌥Return")
                }
            }
            .controlSize(.small)
            .padding(.leading, 32)   // aligns with the command text, as in an expanded row
            .padding(.trailing, 8)
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Add command \(spec.command)")
    }

    private var summary: String {
        var text = "No match. Adds “\(spec.name)”"
        if let port = spec.port { text += " on port \(port)" }
        return text + "."
    }
}
