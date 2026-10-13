import SwiftUI

struct EmptyStateView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Keep long-running commands alive, visible, and one click away.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Add from Project Folder…") { model.requestImport() }
                .buttonStyle(.borderedProminent)
            Button("Add Command…") { model.requestNew() }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
