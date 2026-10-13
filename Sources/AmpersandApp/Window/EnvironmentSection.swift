import AmpersandCore
import AppKit
import SwiftUI

/// Environment variables as a native name/value list with add, remove and import from a
/// `.env` file. Stored as `.env` text in the spec (comments are not kept once edited here).
struct EnvironmentSection: View {
    @Binding var envText: String
    @State private var rows: [Row] = []

    struct Row: Identifiable, Equatable {
        let id = UUID()
        var key: String
        var value: String
    }

    var body: some View {
        Section {
            if rows.isEmpty {
                Text("No variables")
                    .foregroundStyle(.secondary)
            }
            ForEach($rows) { $row in
                HStack {
                    TextField("Name", text: $row.key, prompt: Text(verbatim: "NAME"))
                        .labelsHidden()
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: 200)
                    if !row.key.isEmpty && !Self.isValidName(row.key) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                            .help(Self.nameRule)
                            .accessibilityLabel("Invalid name. \(Self.nameRule)")
                    }
                    TextField("Value", text: $row.value, prompt: Text("Value"))
                        .labelsHidden()
                        .font(.system(.body, design: .monospaced))
                    Button {
                        rows.removeAll { $0.id == row.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove Variable")
                    .accessibilityLabel("Remove \(row.key.isEmpty ? "variable" : row.key)")
                }
            }
            HStack {
                Button("Add Variable", systemImage: "plus") {
                    rows.append(Row(key: "", value: ""))
                }
                Spacer()
                Button("Import from .env File…") { importFile() }
            }
        } header: {
            Text("Environment")
        } footer: {
            if rows.contains(where: { !$0.key.isEmpty && !Self.isValidName($0.key) }) {
                Label("\(Self.nameRule) Variables with an invalid name aren’t saved until it’s fixed.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            } else {
                Text("Added on top of your login shell’s environment.")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { load() }
        .onChange(of: envText) { _, text in
            if text != serialized { load() }   // changed elsewhere (Undo, another edit)
        }
        .onChange(of: rows) { _, _ in
            let text = serialized
            if text != envText { envText = text }
        }
    }

    private var serialized: String {
        // Rows with an invalid name are held back, so one bad row never blocks other edits.
        EnvParser.serialize(rows.compactMap { row in
            let key = row.key.trimmingCharacters(in: .whitespaces)
            return Self.isValidName(key) ? EnvParser.Pair(key: key, value: row.value) : nil
        })
    }

    private func load() {
        rows = EnvParser.parsePairs(envText).map { Row(key: $0.key, value: $0.value) }
    }

    /// Adds the file's variables; a name that already exists takes the file's value.
    private func importFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        for pair in EnvParser.parsePairs(text) {
            if let i = rows.firstIndex(where: { $0.key == pair.key }) {
                rows[i].value = pair.value
            } else {
                rows.append(Row(key: pair.key, value: pair.value))
            }
        }
    }

    private static let nameRule = "Names start with a letter or _ and contain only letters, digits and _."

    private static func isValidName(_ name: String) -> Bool {
        name.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil
    }
}
