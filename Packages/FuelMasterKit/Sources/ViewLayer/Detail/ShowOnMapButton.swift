import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// "Ver en el mapa": centres the map on the station. In the inspector the detail stays open.
struct ShowOnMapButton: View {
    let station: Station
    let keepsDetail: Bool

    @Environment(AppRouter.self) private var router
    @Environment(MapViewModel.self) private var map
    @Environment(\.accentColors) private var accent

    var body: some View {
        Button(action: showOnMap) {
            // The bottom bar shows a Label as its icon alone, which is what this one wants.
            Label { Text("Ver en el mapa", bundle: .module) } icon: { Image(systemName: "map") }
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent.tint)
        }
        .accessibilityIdentifier("showOnMap")
        .accessibilityShowsLargeContentViewer()
    }

    private func showOnMap() {
        map.focus(on: station.coordinate)
        router.showOnMap(station.id, keepsDetail: keepsDetail)
    }
}
