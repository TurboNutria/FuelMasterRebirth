import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

struct EmptyListView: View {
    let reason: EmptyReason
    let showsMapAction: Bool
    let onShowMap: () -> Void
    let onShowAll: () -> Void

    @Environment(\.displayFormat) private var format

    var body: some View {
        switch reason {
        case .noStationsNearby(let product, let nearest):
            let name = String(localized: product.displayName)
            let tip = String(localized: "Mueve el mapa para ver otra zona o cambia de combustible.", bundle: .module)
            let message = nearest.map {
                String(localized: "La más cercana está a \(format.distance(meters: $0)).", bundle: .module) + " " + tip
            } ?? tip
            EmptyStateView(
                systemImage: "fuelpump.slash",
                title: String(localized: "No hay gasolineras con \(name) cerca", bundle: .module),
                message: message,
                actionTitle: showsMapAction ? String(localized: "Ver en el mapa", bundle: .module) : nil,
                action: showsMapAction ? onShowMap : nil
            )
        case .noStationsAtLevel(let level):
            EmptyStateView(
                systemImage: "line.3.horizontal.decrease.circle",
                title: level.emptyTitle,
                message: String(localized: "Prueba con «Todas» o con otro combustible.", bundle: .module),
                actionTitle: String(localized: "Ver todas", bundle: .module),
                action: onShowAll
            )
        case .noFavorites, .noSearchResults:
            EmptyView()
        }
    }
}
