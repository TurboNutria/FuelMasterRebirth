import DesignTokens
import SwiftUI

/// The detail's star: adds or removes the station from Favoritos.
struct FavoriteToggleButton: View {
    let isFavorite: Bool
    let action: () -> Void

    @Environment(\.accentColors) private var accent

    var body: some View {
        Button(action: action) {
            Label {
                isFavorite ? Text("Quitar de favoritos", bundle: .module) : Text("Añadir a favoritos", bundle: .module)
            } icon: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? accent.fill : ColorTokens.textPrimary)
            }
        }
        .sensoryFeedback(.selection, trigger: isFavorite)
    }
}
