import SwiftUI

/// macOS has no toast; feedback sits at the top of the list and never takes focus (spec 4.2).
struct InlineBanner: View {
    let banner: Banner
    let model: AppModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: banner.isProblem ? "exclamationmark.triangle" : "info.circle")
                .foregroundStyle(.secondary)
            Text(banner.message)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            switch banner.action {
            case .retrySave: Button("Retry") { model.retrySave() }
            case .revealConfig: Button("Show in Finder") { model.revealConfig() }
            case nil: EmptyView()
            }
            Button {
                model.banner = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss")
        }
        .controlSize(.small)
        .padding(10)
        .background(.fill.tertiary, in: .rect(cornerRadius: 8, style: .continuous))
    }
}
