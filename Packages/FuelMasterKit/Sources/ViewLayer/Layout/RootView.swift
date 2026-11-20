import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The screens' view models, created once by the App target so they survive layout changes.
public struct RootViewModels {
    public let stationList: StationListViewModel
    public let map: MapViewModel
    public let detail: StationDetailViewModel
    public let favorites: FavoritesViewModel
    public let search: SearchViewModel
    public let settings: SettingsViewModel
    public let onboarding: OnboardingViewModel
    public let tent: TentBoardViewModel

    public init(stationList: StationListViewModel, map: MapViewModel, detail: StationDetailViewModel,
                favorites: FavoritesViewModel, search: SearchViewModel, settings: SettingsViewModel,
                onboarding: OnboardingViewModel, tent: TentBoardViewModel) {
        self.stationList = stationList
        self.map = map
        self.detail = detail
        self.favorites = favorites
        self.search = search
        self.settings = settings
        self.onboarding = onboarding
        self.tent = tent
    }
}

/// Picks the layout from size classes (Bear note 02) and keeps the router in step, so rotating,
/// unfolding the Duo or resizing a window never loses the selection. Applies the look settings
/// (accent, price scale, light / dark) to the whole app, and shows onboarding until it's done.
public struct RootView: View {
    @Bindable var router: AppRouter
    let models: RootViewModels

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var size: CGSize = .zero
    /// The user's last choice, so the panel reopens the way they left it.
    @AppStorage("isPanelCollapsed") private var storedPanelCollapsed = false

    public init(router: AppRouter, models: RootViewModels) {
        self.router = router
        self.models = models
    }

    public var body: some View {
        let settings = models.settings.settings
        let accent = AccentColors.colors(for: settings.accent)
        Group {
            if !models.settings.isLoaded {
                ColorTokens.background.ignoresSafeArea()
            } else if !settings.onboardingCompleted {
                OnboardingScreen(viewModel: models.onboarding)
            } else {
                switch mode {
                case .tabs: TabRootView(router: router)
                case .sideBySide:
                    if isTentShape { TentBoardScreen() } else { SideBySideRootView(router: router) }
                case .split: SplitRootView(router: router)
                }
            }
        }
        .tint(accent.tint)
        .environment(\.accentColors, accent)
        .environment(\.priceScale, settings.priceScale)
        .preferredColorScheme(settings.appearance.colorScheme)
        .environment(router)
        .environment(models.stationList)
        .environment(models.map)
        .environment(models.detail)
        .environment(models.favorites)
        .environment(models.search)
        .environment(models.settings)
        .environment(models.tent)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onChange(of: mode, initial: true) { _, newMode in
            router.layoutDidChange(to: newMode)
        }
        .onAppear { router.isPanelCollapsed = storedPanelCollapsed }
        .onChange(of: router.isPanelCollapsed) { _, collapsed in storedPanelCollapsed = collapsed }
        .task { await models.settings.start() }
    }

    /// A short landscape screen that's nearly square: the closed iPhone Duo held sideways
    /// (about 1.45 : 1; iPhones in landscape are over 1.75 : 1). There the list and map are too
    /// cramped, so it shows the price board instead (canvas: Tent Price Board, QA 2026-10-29).
    private var isTentShape: Bool {
        size.height > 0 && size.width / size.height < 1.6
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

/// Builds the screen for a tab.
struct TabContent: View {
    let tab: AppTab

    @Environment(StationListViewModel.self) private var stationList
    @Environment(FavoritesViewModel.self) private var favorites
    @Environment(SearchViewModel.self) private var search
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        switch tab {
        case .map: MapPane()
        case .list: StationListScreen(viewModel: stationList)
        case .favorites: FavoritesScreen(viewModel: favorites)
        case .search: SearchScreen(viewModel: search)
        case .settings: SettingsScreen(viewModel: settings)
        }
    }
}

/// The selected station's detail, in whichever container the layout uses.
struct DetailPane: View {
    let presentation: DetailPresentation

    @Environment(AppRouter.self) private var router
    @Environment(StationDetailViewModel.self) private var detail

    var body: some View {
        if let id = router.selectedStationID {
            StationDetailScreen(viewModel: detail, stationID: id, presentation: presentation)
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
