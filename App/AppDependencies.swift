import DataLayer
import DomainLayer
import Foundation
import NetworkLayer
import SwiftData
import ViewLayer
import ViewModelLayer
import WidgetKit

/// Composition root: NetworkService → repositories → use cases (Bear note 06).
/// View models get their use cases from here.
final class AppDependencies {
    let cacheContainer: ModelContainer
    let favoritesContainer: ModelContainer

    let localData: LocalDataRepository
    let favorites: FavoritesRepository
    let remote: MinistryRepository
    let location: LocationRepository
    let connectivity: NetworkConnectivityRepository
    let widgets: WidgetRefresher

    let refreshPrices: RefreshPrices
    let backfillHistory: BackfillHistory
    let resolveProvinces: ResolveProvinces
    let observeNearbyStations: ObserveNearbyStations
    let observeConnectivity: ObserveConnectivity
    let observeSettings: ObserveSettings
    let updateSettings: UpdateSettings
    let locateUser: LocateUser
    let getStationDetail: GetStationDetail
    let getPriceHistory: GetPriceHistory
    let toggleFavorite: ToggleFavorite
    let observeFavorites: ObserveFavorites
    let reorderFavorites: ReorderFavorites
    let observeICloudStatus: ObserveICloudStatus
    let searchStations: SearchStations
    let completeOnboarding: CompleteOnboarding
    let getDataSourceInfo: GetDataSourceInfo

    init() throws {
        cacheContainer = try PersistenceFactory.cacheContainer()
        favoritesContainer = try PersistenceFactory.favoritesContainer()

        let network = NetworkService()
        localData = LocalDataRepository(container: cacheContainer, defaults: PersistenceFactory.sharedDefaults())
        favorites = FavoritesRepository(container: favoritesContainer)
        remote = MinistryRepository(network: network)
        location = LocationRepository()
        connectivity = NetworkConnectivityRepository()
        widgets = WidgetRefresher()

        refreshPrices = RefreshPrices(remote: remote, cache: localData, widgets: widgets)
        backfillHistory = BackfillHistory(remote: remote, cache: localData)
        resolveProvinces = ResolveProvinces(provinces: localData)
        observeNearbyStations = ObserveNearbyStations(cache: localData, favorites: favorites)
        observeConnectivity = ObserveConnectivity(connectivity: connectivity)
        observeSettings = ObserveSettings(settings: localData)
        updateSettings = UpdateSettings(settings: localData)
        locateUser = LocateUser(location: location)
        getStationDetail = GetStationDetail(cache: localData, favorites: favorites)
        getPriceHistory = GetPriceHistory(cache: localData, backfill: backfillHistory)
        toggleFavorite = ToggleFavorite(favorites: favorites)
        observeFavorites = ObserveFavorites(favorites: favorites, cache: localData)
        reorderFavorites = ReorderFavorites(favorites: favorites)
        observeICloudStatus = ObserveICloudStatus(favorites: favorites)
        searchStations = SearchStations(cache: localData, provinces: localData, favorites: favorites,
                                        refreshPrices: refreshPrices)
        completeOnboarding = CompleteOnboarding(settings: localData)
        getDataSourceInfo = GetDataSourceInfo(cache: localData, provinces: localData)
    }

    /// Every screen's view model, created once and kept by the app.
    @MainActor func makeViewModels() -> RootViewModels {
        RootViewModels(
            stationList: makeStationListViewModel(), map: makeMapViewModel(), detail: makeStationDetailViewModel(),
            favorites: makeFavoritesViewModel(), search: makeSearchViewModel(),
            settings: SettingsViewModel(observeSettings: observeSettings, updateSettings: updateSettings,
                                        resolveProvinces: resolveProvinces, getDataSourceInfo: getDataSourceInfo),
            onboarding: OnboardingViewModel(completeOnboarding: completeOnboarding, resolveProvinces: resolveProvinces,
                                            locateUser: locateUser),
            tent: TentBoardViewModel(getDetail: getStationDetail, getHistory: getPriceHistory,
                                     backfillHistory: backfillHistory)
        )
    }

    /// Created once and kept by the app, so screen state survives layout changes.
    @MainActor func makeStationListViewModel() -> StationListViewModel {
        StationListViewModel(
            observeNearby: observeNearbyStations, refreshPrices: refreshPrices, resolveProvinces: resolveProvinces,
            observeConnectivity: observeConnectivity, observeSettings: observeSettings,
            updateSettings: updateSettings, locateUser: locateUser, toggleFavorite: toggleFavorite
        )
    }

    @MainActor func makeMapViewModel() -> MapViewModel {
        MapViewModel(
            observeNearby: observeNearbyStations, refreshPrices: refreshPrices, resolveProvinces: resolveProvinces,
            observeConnectivity: observeConnectivity, observeSettings: observeSettings,
            updateSettings: updateSettings, locateUser: locateUser
        )
    }
}

extension AppDependencies {
    @MainActor func makeStationDetailViewModel() -> StationDetailViewModel {
        StationDetailViewModel(
            getDetail: getStationDetail, getHistory: getPriceHistory, toggleFavorite: toggleFavorite,
            observeSettings: observeSettings, locateUser: locateUser
        )
    }

    @MainActor func makeFavoritesViewModel() -> FavoritesViewModel {
        FavoritesViewModel(
            observeFavorites: observeFavorites, toggleFavorite: toggleFavorite, reorderFavorites: reorderFavorites,
            observeICloudStatus: observeICloudStatus, refreshPrices: refreshPrices, backfillHistory: backfillHistory,
            observeSettings: observeSettings, locateUser: locateUser
        )
    }

    @MainActor func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(
            searchStations: searchStations, resolveProvinces: resolveProvinces, toggleFavorite: toggleFavorite,
            observeSettings: observeSettings, locateUser: locateUser
        )
    }
}

/// Tells WidgetKit to reload every timeline after new prices are saved.
struct WidgetRefresher: WidgetRefreshing {
    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
