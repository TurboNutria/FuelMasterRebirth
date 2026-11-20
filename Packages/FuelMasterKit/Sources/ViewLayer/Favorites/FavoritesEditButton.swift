import SwiftUI

/// "Editar" / "Hecho": turns reordering on and off.
struct FavoritesEditButton: View {
    @Binding var isEditing: Bool
    let isEnabled: Bool

    var body: some View {
        Button(action: toggle) {
            isEditing ? Text("Hecho", bundle: .module) : Text("Editar", bundle: .module)
        }
        .font(.body.weight(.semibold))
        // Borderless keeps the accent tint inside a plain list row and limits the tap to the text.
        .buttonStyle(.borderless)
        .disabled(!isEnabled)
    }

    private func toggle() {
        withAnimation { isEditing.toggle() }
    }
}
