import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The peek and menu, once the favourite has a price to show.
struct FavoriteContextMenu: ViewModifier {
    let row: FavoriteRow
    let onRemove: () -> Void
    let onOpen: () -> Void

    func body(content: Content) -> some View {
        if let summary = row.summary, let hours = row.hours {
            content.stationContextMenu(summary, hours: hours, isFavorite: true,
                                       onToggleFavorite: onRemove, onOpen: onOpen)
        } else {
            content
        }
    }
}
