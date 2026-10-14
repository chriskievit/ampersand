import SwiftUI

extension View {
    /// Asks for a group's name before the group exists, so no placeholder is left to rename.
    /// Create stays disabled while the name is blank.
    func newGroupAlert(isPresented: Binding<Bool>, onCreate: @escaping (String) -> Void) -> some View {
        modifier(NewGroupAlert(isPresented: isPresented, onCreate: onCreate))
    }
}

private struct NewGroupAlert: ViewModifier {
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void
    @State private var name = ""

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    func body(content: Content) -> some View {
        content
            .alert("New group", isPresented: $isPresented) {
                TextField("Name", text: $name)
                Button("Create") { onCreate(trimmed) }
                    .disabled(trimmed.isEmpty)
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: isPresented) { _, presented in
                if presented { name = "" }
            }
    }
}
