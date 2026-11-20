import DesignTokens
import SwiftUI
import ViewModelLayer

/// Favoritos' title with Editar beside it (under it at the largest text sizes), then the
/// cheapest favourite.
struct FavoritesHeader: View {
    let viewModel: FavoritesViewModel
    @Binding var isEditing: Bool

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let title = ScreenTitle(Text("Favoritos", bundle: .module))
            let editButton = FavoritesEditButton(isEditing: $isEditing, isEnabled: viewModel.state.content != nil)
            if typeSize.isAccessibilitySize {
                // Title alone, as in Gasolineras, so it doesn't run into Editar.
                VStack(alignment: .leading, spacing: 8) { title; editButton }
                    .padding(.top, 8)
            } else {
                HStack(alignment: .lastTextBaseline) {
                    title
                    Spacer(minLength: 8)
                    editButton
                }
                .padding(.top, 8)
            }
            if let best = viewModel.state.content?.best { BestFavoriteCard(best: best) }
        }
        .padding(.bottom, 24)
    }
}
