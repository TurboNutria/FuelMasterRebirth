// The package also builds for iOS and macOS (tests, ViewLayer); the watch views exist only on watchOS.
#if os(watchOS)
import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The view models the watch app creates once (WatchDependencies) and hands to the root view.
@MainActor
public struct WatchRootModels {
    let look: WatchLookViewModel
    let nearby: StationListViewModel
    let favorites: FavoritesViewModel
    let makeDetail: @MainActor () -> WatchStationDetailViewModel

    public init(look: WatchLookViewModel, nearby: StationListViewModel, favorites: FavoritesViewModel,
                makeDetail: @escaping @MainActor () -> WatchStationDetailViewModel) {
        self.look = look
        self.nearby = nearby
        self.favorites = favorites
        self.makeDetail = makeDetail
    }
}

/// Where the app opens. DEBUG launch arguments use it for screenshots, since the simulator
/// panel can't drive a watch.
public struct WatchLaunchState: Sendable {
    public enum Page: Int, Sendable { case nearby, favorites }

    public var page: Page
    /// A detail pushed on that page.
    public var station: StationID?
    public var showsFuelPicker: Bool
    /// Opens the lists scrolled to the end, to see what's below the first screen.
    public var scrollsToBottom: Bool

    public init(page: Page = .nearby, station: StationID? = nil, showsFuelPicker: Bool = false,
                scrollsToBottom: Bool = false) {
        self.page = page
        self.station = station
        self.showsFuelPicker = showsFuelPicker
        self.scrollsToBottom = scrollsToBottom
    }
}

/// The watch app's two pages, Cerca and Favoritas, turned with the crown (canvas: Apple Watch).
public struct WatchRootView: View {
    let models: WatchRootModels
    @State private var page: WatchLaunchState.Page
    @State private var nearbyPath: [StationID]
    @State private var favoritesPath: [StationID]
    @State private var showsFuelPicker: Bool
    private let scrollAnchor: UnitPoint?

    public init(models: WatchRootModels, launch: WatchLaunchState = WatchLaunchState()) {
        self.models = models
        _page = State(initialValue: launch.page)
        _nearbyPath = State(initialValue: launch.page == .nearby ? launch.station.map { [$0] } ?? [] : [])
        _favoritesPath = State(initialValue: launch.page == .favorites ? launch.station.map { [$0] } ?? [] : [])
        _showsFuelPicker = State(initialValue: launch.showsFuelPicker)
        scrollAnchor = launch.scrollsToBottom ? .bottom : nil
    }

    public var body: some View {
        let accent = AccentColors.colors(for: models.look.accent)
        TabView(selection: $page) {
            NavigationStack(path: $nearbyPath) {
                NearbyPage(viewModel: models.nearby) { showsFuelPicker = true }
                    .navigationDestination(for: StationID.self) { detail(for: $0) }
                    .toolbarForegroundStyle(accent.tint, for: .navigationBar)
            }
            .tag(WatchLaunchState.Page.nearby)
            NavigationStack(path: $favoritesPath) {
                FavoritesPage(viewModel: models.favorites) { showsFuelPicker = true }
                    .navigationDestination(for: StationID.self) { detail(for: $0) }
                    .toolbarForegroundStyle(accent.tint, for: .navigationBar)
            }
            .tag(WatchLaunchState.Page.favorites)
        }
        .tabViewStyle(.verticalPage)
        .defaultScrollAnchor(scrollAnchor)
        .environment(\.scrollsToBottom, scrollAnchor == .bottom)
        .sheet(isPresented: $showsFuelPicker) {
            FuelPicker(products: models.nearby.offeredProducts, chosen: models.nearby.product) { product in
                Task { await models.nearby.select(product) }
            }
        }
        .tint(accent.tint)
        .environment(\.accentColors, accent)
        .environment(\.priceScale, models.look.priceScale)
        .task { await models.look.start() }
    }

    private func detail(for id: StationID) -> some View {
        WatchDetailScreen(id: id, viewModel: models.makeDetail())
    }
}
#endif
