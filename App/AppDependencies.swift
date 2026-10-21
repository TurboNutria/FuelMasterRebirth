import DataLayer
import DomainLayer
import Foundation
import NetworkLayer
import SwiftData
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
    }
}

/// Tells WidgetKit to reload every timeline after new prices are saved.
struct WidgetRefresher: WidgetRefreshing {
    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
