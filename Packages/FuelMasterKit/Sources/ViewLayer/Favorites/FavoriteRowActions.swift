import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// "Quitar de favoritos" and, once the station is loaded, "Cómo llegar".
struct FavoriteRowActions: ViewModifier {
    let station: Station?
    let onRemove: () -> Void

    func body(content: Content) -> some View {
        if let station {
            content.stationRowActions(station, isFavorite: true, onToggleFavorite: onRemove)
        } else {
            content.accessibilityAction(named: Text("Quitar de favoritos", bundle: .module), onRemove)
        }
    }
}
