import AmpersandCore
import AppKit
import SwiftUI

/// `.env`-style text with line errors shown once the field loses focus (spec 4.5).
struct EnvEditor: View {
    @Binding var text: String
    @Binding var envFile: String
    let errors: [EnvParseError]
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent("Environment") {
            VStack(alignment: .leading, spacing: 6) {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72)
                    .padding(4)
                    .background(.background, in: .rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                    .accessibilityLabel("Environment variables")
                if !focused {
                    ForEach(errors, id: \.line) { error in
                        Label {
                            Text(verbatim: "Line \(error.line): \(error.message)")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        }
                    }
                }
                Text("One KEY=value per line. Lines that start with # are comments.")
                    .foregroundStyle(.secondary)
                if envFile.isEmpty {
                    Button("Load from File…") { chooseFile() }
                } else {
                    HStack {
                        Text("Also reads \(envFile) at each start")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Remove") { envFile = "" }
                    }
                }
            }
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.prompt = "Use File"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        envFile = (url.path as NSString).abbreviatingWithTildeInPath
    }
}
