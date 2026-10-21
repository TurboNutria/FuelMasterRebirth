import DomainLayer
import SwiftUI
import ViewModelLayer

/// Picks the layout from size classes (Bear note 02) and keeps the router in step, so rotating,
/// unfolding the Duo or resizing a window never loses the selection.
public struct RootView: View {
    @Bindable var router: AppRouter
    let stationList: StationListViewModel
    let map: MapViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accentColors) private var accent

    /// View models are created once by the App target, so they survive layout changes.
    public init(router: AppRouter, stationList: StationListViewModel, map: MapViewModel) {
        self.router = router
        self.stationList = stationList
        self.map = map
    }

    public var body: some View {
        Group {
            switch mode {
            case .tabs: TabRootView(router: router)
            case .sideBySide: SideBySideRootView(router: router)
            case .split: SplitRootView(router: router)
            }
        }
        .tint(accent.tint)
        .environment(router)
        .environment(stationList)
        .environment(map)
        .onChange(of: mode, initial: true) { _, newMode in
            router.layoutDidChange(to: newMode)
        }
    }

    private var mode: LayoutMode {
        LayoutMode(horizontalIsRegular: horizontalSizeClass == .regular,
                   verticalIsCompact: verticalSizeClass == .compact)
    }
}

extension AppTab {
    var title: Text {
        switch self {
        case .map: Text("Mapa", bundle: .module)
        case .list: Text("Gasolineras", bundle: .module)
        case .favorites: Text("Favoritos", bundle: .module)
        case .settings: Text("Ajustes", bundle: .module)
        case .search: Text("Buscar", bundle: .module)
        }
    }

    var systemImage: String {
        switch self {
        case .map: "map"
        case .list: "fuelpump"
        case .favorites: "star"
        case .settings: "gearshape"
        case .search: "magnifyingglass"
        }
    }
}

/// Builds the screen for a tab. Each phase (U2–U6) replaces one placeholder.
struct TabContent: View {
    let tab: AppTab

    @Environment(StationListViewModel.self) private var stationList

    var body: some View {
        switch tab {
        case .map: MapPane()
        case .list: StationListScreen(viewModel: stationList)
        default: PlaceholderScreen(tab: tab)
        }
    }
}

/// The map in every layout: its own tab, or the pane beside the list.
struct MapPane: View {
    @Environment(MapViewModel.self) private var map

    var body: some View {
        MapScreen(viewModel: map)
    }
}
