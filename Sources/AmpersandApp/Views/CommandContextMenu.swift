import AmpersandCore
import SwiftUI

/// Every action for one command (spec 4.2). Shared by the popover and the window sidebar.
struct CommandContextMenu: View {
    let runtime: CommandRuntime
    let model: AppModel

    var body: some View {
        Button(runtime.status.isActive ? "Stop" : "Start") { model.toggle(runtime.id) }
        Button("Restart") { model.restart(runtime.id) }
            .disabled(!runtime.status.isActive)
        Divider()
        Button("Show log") { model.showLog(runtime.id) }
        Button("Open in browser") { model.openInBrowser(runtime.id) }
            .disabled(runtime.spec.port == nil)
        Divider()
        Button("Edit…") { model.requestEdit(runtime.id) }
        Button("Duplicate") { model.duplicate(runtime.id) }
        Menu("Move to group") {
            Button("No group") { model.move(runtime.id, toGroup: nil) }
                .disabled(runtime.spec.group == nil)
            Divider()
            ForEach(model.config.groups) { group in
                Button(group.name) { model.move(runtime.id, toGroup: group.id) }
                    .disabled(runtime.spec.group == group.id)
            }
        }
        Divider()
        Button("Delete", role: .destructive) { model.delete(runtime.id) }
    }
}
