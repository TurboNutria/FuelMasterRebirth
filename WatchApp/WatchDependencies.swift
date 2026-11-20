import DataLayer
import DomainLayer
import Foundation
import NetworkLayer
import SwiftData
import ViewModelLayer
import WatchViewLayer

/// The watch's composition root (Bear note 06, "Apple Watch"): its own price cache and ministry
/// downloads, with settings and favourites mirrored from the iPhone. The same use cases and
/// view models as the iPhone, except the smaller detail.
final class WatchDependencies {
    let cacheContainer: ModelContainer
    let localData: LocalDataRepository
    let mirror: CompanionMirrorRepository
    let locateUser: LocateUser

    private let refreshPrices: RefreshPrices
    private let refreshFavorites: RefreshFavorites
    private let resolveArea: ResolveArea
    private let observeNearbyStations: ObserveNearbyStations
    private let observeConnectivity: ObserveConnectivity
    private let observeSettings: ObserveSettings
    private let updateSettings: UpdateSettings
    private let toggleFavorite: ToggleFavorite
    private let observeFavorites: ObserveFavorites
    private let reorderFavorites: ReorderFavorites
    private let observeICloudStatus: ObserveICloudStatus
    private let rememberArea: RememberArea
    private let getStationDetail: GetStationDetail

    /// Created on first use.
    static let shared = Result { try WatchDependencies() }

    init() throws {
        // No App Group on the watch: the cache lives in the app's own container.
        cacheContainer = try PersistenceFactory.cacheContainer()
        localData = LocalDataRepository(container: cacheContainer)
        mirror = CompanionMirrorRepository(session: WatchConnectivitySession())
        let remote = MinistryRepository(network: NetworkService())
        locateUser = LocateUser(location: LocationRepository())

        refreshPrices = RefreshPrices(remote: remote, cache: localData)
        refreshFavorites = RefreshFavorites(refreshPrices: refreshPrices,
                                            backfill: BackfillHistory(remote: remote, cache: localData))
        resolveArea = ResolveArea(provinces: localData)
        observeNearbyStations = ObserveNearbyStations(cache: localData, favorites: mirror)
        observeConnectivity = ObserveConnectivity(connectivity: NetworkConnectivityRepository())
        observeSettings = ObserveSettings(settings: mirror)
        updateSettings = UpdateSettings(settings: mirror)
        toggleFavorite = ToggleFavorite(favorites: mirror)
        observeFavorites = ObserveFavorites(favorites: mirror, cache: localData)
        reorderFavorites = ReorderFavorites(favorites: mirror)
        observeICloudStatus = ObserveICloudStatus(favorites: mirror)
        rememberArea = RememberArea(settings: mirror, provinces: localData)
        getStationDetail = GetStationDetail(cache: localData, favorites: mirror)
    }

    /// Created once and kept by the app.
    @MainActor func makeModels() -> WatchRootModels {
        WatchRootModels(
            look: WatchLookViewModel(observeSettings: observeSettings),
            nearby: StationListViewModel(
                observeNearby: observeNearbyStations, refreshPrices: refreshPrices,
                resolveArea: resolveArea, observeConnectivity: observeConnectivity,
                observeSettings: observeSettings, updateSettings: updateSettings, locateUser: locateUser,
                toggleFavorite: toggleFavorite, rememberArea: rememberArea
            ),
            favorites: FavoritesViewModel(
                observeFavorites: observeFavorites, toggleFavorite: toggleFavorite,
                reorderFavorites: reorderFavorites, observeICloudStatus: observeICloudStatus,
                refreshPrices: refreshPrices, refreshFavorites: refreshFavorites,
                observeSettings: observeSettings, locateUser: locateUser
            ),
            makeDetail: { [getStationDetail, toggleFavorite, observeSettings, locateUser] in
                WatchStationDetailViewModel(getDetail: getStationDetail, toggleFavorite: toggleFavorite,
                                            observeSettings: observeSettings, locateUser: locateUser)
            }
        )
    }
}
