import Foundation

// Contracts the use cases depend on. Implementations live in DataLayer (and the App target for
// WidgetRefreshing), so use cases and view models can be tested with fakes and the v2 backend can
// replace MinistryRepository without touching anything above the Data layer.

/// Remote prices. v1: MinistryRepository. v2: the FuelMaster backend.
public protocol StationRemoteRepository: Sendable {
    func currentPrices(province: ProvinceID) async throws -> ProvinceSnapshot
    func history(province: ProvinceID, product: Product, day: Date) async throws -> HistorySnapshot
}

/// Local cache of stations, prices and history. Implemented by LocalDataRepository.
public protocol StationCacheRepository: Sendable {
    func stations(in provinces: [ProvinceID]) async throws -> [Station]
    func station(id: StationID) async throws -> Station?
    func save(_ snapshot: ProvinceSnapshot, fetchedAt: Date) async throws
    func freshness(of province: ProvinceID) async throws -> Freshness?
    func history(station: StationID, product: Product, since day: Date) async throws -> [HistoryPoint]
    func areaHistory(provinces: [ProvinceID], product: Product, since day: Date) async throws -> [HistoryPoint]
    func historyDays(province: ProvinceID, product: Product, since day: Date) async throws -> Set<Date>
    func save(_ history: HistorySnapshot) async throws
    func deleteHistory(before day: Date) async throws
    /// Emits whenever the cache changes, so observers can reload.
    func changes() async -> AsyncStream<Void>
}

/// Bundled province outlines and municipality catalogue. Implemented by LocalDataRepository.
public protocol ProvinceRepository: Sendable {
    func allProvinces() async -> [Province]
    func province(at coordinate: Coordinate) async -> ProvinceID?
    func provinces(intersecting bounds: BoundingBox) async -> [ProvinceID]
    func municipalities(matching text: String) async -> [Municipality]
}

/// Per-device settings. Implemented by LocalDataRepository.
public protocol SettingsRepository: Sendable {
    func current() async -> Settings
    /// Applies `change` to the latest settings and saves the result in one step, so a change made
    /// at the same time by another caller is never overwritten. Returns the saved settings.
    @discardableResult
    func update(_ change: @Sendable (inout Settings) -> Void) async -> Settings
    func changes() async -> AsyncStream<Settings>
}

public struct FavoriteEntry: Hashable, Sendable {
    public let stationID: StationID
    public let provinceID: ProvinceID
    public let order: Int

    public init(stationID: StationID, provinceID: ProvinceID, order: Int) {
        self.stationID = stationID
        self.provinceID = provinceID
        self.order = order
    }
}

/// Favourites (SwiftData, CloudKit-ready). Implemented by FavoritesRepository.
public protocol FavoriteStationsRepository: Sendable {
    func favorites() async throws -> [FavoriteEntry]
    func add(_ station: StationID, province: ProvinceID) async throws
    func remove(_ station: StationID) async throws
    func move(from source: Int, to destination: Int) async throws
    func changes() async -> AsyncStream<[FavoriteEntry]>
    func iCloudStatus() async -> AsyncStream<ICloudStatus>
}

public enum LocationAuthorization: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
}

/// Device location. Implemented by LocationRepository (Core Location).
public protocol UserLocationRepository: Sendable {
    func authorization() async -> LocationAuthorization
    func requestAuthorization() async -> LocationAuthorization
    func updates() async -> AsyncStream<Coordinate>
}

/// Network reachability. Implemented in DataLayer on top of NetworkLayer's monitor.
public protocol ConnectivityRepository: Sendable {
    func updates() async -> AsyncStream<Connectivity>
}

/// Tells the widgets to reload their timelines. Implemented in the App target.
public protocol WidgetRefreshing: Sendable {
    func reloadAll()
}
