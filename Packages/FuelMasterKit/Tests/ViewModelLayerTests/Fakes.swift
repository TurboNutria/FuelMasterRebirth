import DomainLayer
import Foundation
import ViewModelLayer

// Fake repositories behind real use cases, so view models are tested end to end above Data.

extension Fixtures {
    static let sol = Coordinate(latitude: 40.4169, longitude: -3.7035)

    static func station(_ id: String, diesel: String?, metersNorth: Double = 500,
                        hours: OpeningHours = OpeningHours(rawText: "L-D: 24H", schedule: .alwaysOpen)) -> Station {
        var prices: [Product: Price] = [:]
        if let diesel { prices[.diesel] = Price(amount: Decimal(string: diesel)!, product: .diesel) }
        prices[.petrol95E5] = Price(amount: Decimal(string: "1.700")!, product: .petrol95E5)
        let coordinate = Coordinate(latitude: sol.latitude + metersNorth / 111_000, longitude: sol.longitude)
        return Station(
            id: StationID(id), name: "Station \(id)",
            address: Address(street: "C/ Test, \(id)", postcode: "28001", locality: "Madrid", municipality: "Madrid", province: "Madrid"),
            coordinate: coordinate, roadSide: .notApplicable, hours: hours,
            provinceID: ProvinceID("28"), municipalityID: MunicipalityID("4354"), prices: prices
        )
    }

    static let madrid = Province(
        id: ProvinceID("28"), name: "Madrid", regionID: "13",
        bounds: BoundingBox(minLatitude: 39.8, minLongitude: -4.6, maxLatitude: 41.2, maxLongitude: -3.0),
        outline: [],
        samples: [sol, Coordinate(latitude: 40.43, longitude: -3.69), Coordinate(latitude: 41.0, longitude: -3.2)]
    )
}

/// A stream the test can push values into.
final class Channel<Value: Sendable>: Sendable {
    let stream: AsyncStream<Value>
    private let continuation: AsyncStream<Value>.Continuation

    init() {
        (stream, continuation) = AsyncStream<Value>.makeStream()
    }

    func send(_ value: Value) { continuation.yield(value) }
}

actor FakeRemote: StationRemoteRepository {
    var snapshots: [ProvinceID: ProvinceSnapshot]
    var error: DomainError?
    let delay: Duration?
    private(set) var calls = 0

    init(snapshots: [ProvinceID: ProvinceSnapshot] = [:], error: DomainError? = nil, delay: Duration? = nil) {
        self.snapshots = snapshots
        self.error = error
        self.delay = delay
    }

    func setError(_ error: DomainError?) { self.error = error }

    func currentPrices(province: ProvinceID) async throws -> ProvinceSnapshot {
        calls += 1
        if let delay { try await Task.sleep(for: delay) }
        if let error { throw error }
        guard let snapshot = snapshots[province] else { throw DomainError.notFound }
        return snapshot
    }

    func history(province: ProvinceID, product: Product, day: Date) async throws -> HistorySnapshot {
        if let error { throw error }
        return HistorySnapshot(provinceID: province, product: product, day: day, prices: [:])
    }
}

actor FakeCache: StationCacheRepository {
    var stored: [ProvinceID: [Station]]
    var freshnessByProvince: [ProvinceID: Freshness]
    private var continuations: [AsyncStream<Void>.Continuation] = []

    init(stored: [ProvinceID: [Station]] = [:], freshness: [ProvinceID: Freshness] = [:]) {
        self.stored = stored
        self.freshnessByProvince = freshness
    }

    func stations(in provinces: [ProvinceID]) async throws -> [Station] { provinces.flatMap { stored[$0] ?? [] } }
    func station(id: StationID) async throws -> Station? { stored.values.flatMap { $0 }.first { $0.id == id } }
    func save(_ snapshot: ProvinceSnapshot, fetchedAt: Date) async throws {
        stored[snapshot.provinceID] = snapshot.stations
        freshnessByProvince[snapshot.provinceID] = Freshness(snapshotDate: snapshot.snapshotDate, fetchedAt: fetchedAt)
        for continuation in continuations { continuation.yield() }
    }
    func freshness(of province: ProvinceID) async throws -> Freshness? { freshnessByProvince[province] }
    /// Daily prices per fuel, the same for every station.
    var historyByProduct: [Product: [HistoryPoint]] = [:]
    func setHistory(_ points: [HistoryPoint], for product: Product) { historyByProduct[product] = points }
    func history(station: StationID, product: Product, since day: Date) async throws -> [HistoryPoint] {
        (historyByProduct[product] ?? []).filter { $0.day >= day }
    }
    func areaHistory(provinces: [ProvinceID], product: Product, since day: Date) async throws -> [HistoryPoint] { [] }
    func historyDays(province: ProvinceID, product: Product, since day: Date) async throws -> Set<Date> { [] }
    func save(_ history: HistorySnapshot) async throws {}
    func deleteHistory(before day: Date) async throws {}
    func changes() async -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        continuations.append(continuation)
        return stream
    }
}

actor FakeFavorites: FavoriteStationsRepository {
    private(set) var entries: [FavoriteEntry] = []
    private var continuations: [AsyncStream<[FavoriteEntry]>.Continuation] = []

    func favorites() async throws -> [FavoriteEntry] { entries }
    func add(_ station: StationID, province: ProvinceID) async throws {
        entries.append(FavoriteEntry(stationID: station, provinceID: province, order: entries.count))
        for continuation in continuations { continuation.yield(entries) }
    }
    func remove(_ station: StationID) async throws {
        entries.removeAll { $0.stationID == station }
        for continuation in continuations { continuation.yield(entries) }
    }
    func move(from source: Int, to destination: Int) async throws {
        let entry = entries.remove(at: source)
        entries.insert(entry, at: min(max(0, destination), entries.count))
        for continuation in continuations { continuation.yield(entries) }
    }
    func changes() async -> AsyncStream<[FavoriteEntry]> {
        let (stream, continuation) = AsyncStream<[FavoriteEntry]>.makeStream()
        continuations.append(continuation)
        return stream
    }
    func iCloudStatus() async -> AsyncStream<ICloudStatus> { AsyncStream { _ in } }
}

struct FakeProvinces: ProvinceRepository {
    func allProvinces() async -> [Province] { [Fixtures.madrid] }
    func province(at coordinate: Coordinate) async -> ProvinceID? { ProvinceID("28") }
    func provinces(intersecting bounds: BoundingBox) async -> [ProvinceID] { [ProvinceID("28")] }
    func municipalities(matching text: String) async -> [Municipality] { [] }
}

actor FakeSettings: SettingsRepository {
    private(set) var settings: Settings
    let channel = Channel<Settings>()

    init(_ settings: Settings = .default) { self.settings = settings }

    func current() async -> Settings { settings }
    @discardableResult
    func update(_ change: @Sendable (inout Settings) -> Void) async -> Settings {
        change(&settings)
        channel.send(settings)
        return settings
    }
    func changes() async -> AsyncStream<Settings> { channel.stream }
}

struct FakeLocation: UserLocationRepository {
    var authorization: LocationAuthorization = .authorized
    var fix: Coordinate? = Fixtures.sol
    /// Holds the fix back, like a device that takes a while to find itself.
    var delay: Duration?

    func authorization() async -> LocationAuthorization { authorization }
    func requestAuthorization() async -> LocationAuthorization { authorization }
    func updates() async -> AsyncStream<Coordinate> {
        let (fix, delay) = (fix, delay)
        return AsyncStream { continuation in
            let task = Task {
                if let delay { try? await Task.sleep(for: delay) }
                if let fix, !Task.isCancelled { continuation.yield(fix) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct FakeConnectivity: ConnectivityRepository {
    let channel = Channel<Connectivity>()
    func updates() async -> AsyncStream<Connectivity> { channel.stream }
}

/// Everything a StationListViewModel needs, with handles on the fakes.
@MainActor
struct ListHarness {
    static let now = Fixtures.date(2026, 10, 20, 22, 30)

    let remote: FakeRemote
    let cache: FakeCache
    let settings: FakeSettings
    let connectivity = FakeConnectivity()
    let favorites = FakeFavorites()
    let viewModel: StationListViewModel

    init(cached: [Station]? = nil, remote stations: [Station] = [], remoteError: DomainError? = nil,
         location: FakeLocation = FakeLocation(), settings: Settings = .default,
         firstFixTimeout: Duration = .seconds(6)) {
        let now = Self.now
        let snapshotDate = now.addingTimeInterval(-12 * 60)
        remote = FakeRemote(snapshots: [ProvinceID("28"): ProvinceSnapshot(provinceID: ProvinceID("28"), stations: stations,
                                                                          snapshotDate: snapshotDate)],
                            error: remoteError)
        cache = FakeCache(
            stored: cached.map { [ProvinceID("28"): $0] } ?? [:],
            // Cached data counts as fresh, so only a forced refresh would refetch it.
            freshness: cached == nil ? [:] : [ProvinceID("28"): Freshness(snapshotDate: snapshotDate, fetchedAt: now)]
        )
        self.settings = FakeSettings(settings)
        viewModel = StationListViewModel(
            observeNearby: ObserveNearbyStations(cache: cache, favorites: favorites, now: { now }),
            refreshPrices: RefreshPrices(remote: remote, cache: cache, now: { now }),
            resolveArea: ResolveArea(provinces: FakeProvinces()),
            observeConnectivity: ObserveConnectivity(connectivity: connectivity),
            observeSettings: ObserveSettings(settings: self.settings),
            updateSettings: UpdateSettings(settings: self.settings),
            locateUser: LocateUser(location: location, firstFixTimeout: firstFixTimeout),
            toggleFavorite: ToggleFavorite(favorites: favorites),
            format: DisplayFormat(locale: Locale(identifier: "es_ES")),
            now: { now }
        )
    }

    /// Starts the screen and waits until `condition` holds (or fails after ~2 s).
    func start(until condition: @MainActor (StationListViewModel) -> Bool) async -> Task<Void, Never> {
        let task = Task { await viewModel.start() }
        await waitUntil(condition)
        return task
    }

    func waitUntil(_ condition: @MainActor (StationListViewModel) -> Bool) async {
        for _ in 0..<200 {
            if condition(viewModel) { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// Everything a MapViewModel needs, with handles on the fakes.
@MainActor
struct MapHarness {
    let remote: FakeRemote
    let cache: FakeCache
    let connectivity = FakeConnectivity()
    let viewModel: MapViewModel

    init(cached: [Station]? = nil, remote stations: [Station] = [], remoteDelay: Duration? = nil,
         location: FakeLocation = FakeLocation(), firstFixTimeout: Duration = .seconds(6)) {
        let now = ListHarness.now
        let snapshotDate = now.addingTimeInterval(-12 * 60)
        remote = FakeRemote(snapshots: [ProvinceID("28"): ProvinceSnapshot(provinceID: ProvinceID("28"), stations: stations,
                                                                          snapshotDate: snapshotDate)],
                            delay: remoteDelay)
        cache = FakeCache(
            stored: cached.map { [ProvinceID("28"): $0] } ?? [:],
            freshness: cached == nil ? [:] : [ProvinceID("28"): Freshness(snapshotDate: snapshotDate, fetchedAt: now)]
        )
        let settings = FakeSettings()
        viewModel = MapViewModel(
            observeNearby: ObserveNearbyStations(cache: cache, favorites: FakeFavorites(), now: { now }),
            refreshPrices: RefreshPrices(remote: remote, cache: cache, now: { now }),
            resolveProvinces: ResolveProvinces(provinces: FakeProvinces()),
            resolveArea: ResolveArea(provinces: FakeProvinces()),
            observeConnectivity: ObserveConnectivity(connectivity: connectivity),
            observeSettings: ObserveSettings(settings: settings),
            updateSettings: UpdateSettings(settings: settings),
            locateUser: LocateUser(location: location, firstFixTimeout: firstFixTimeout),
            settleDelay: .zero,
            now: { now }
        )
    }

    func waitUntil(_ condition: @MainActor (MapViewModel) -> Bool) async {
        for _ in 0..<200 {
            if condition(viewModel) { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// Everything a StationDetailViewModel needs, with handles on the fakes.
@MainActor
struct DetailHarness {
    let remote: FakeRemote
    let cache: FakeCache
    let favorites = FakeFavorites()
    let settings: FakeSettings
    let viewModel: StationDetailViewModel

    init(stations: [Station], remoteError: DomainError? = nil, settings: Settings = .default) {
        let now = ListHarness.now
        remote = FakeRemote(error: remoteError)
        cache = FakeCache(stored: [ProvinceID("28"): stations],
                          freshness: [ProvinceID("28"): Freshness(snapshotDate: now.addingTimeInterval(-12 * 60), fetchedAt: now)])
        self.settings = FakeSettings(settings)
        viewModel = StationDetailViewModel(
            getDetail: GetStationDetail(cache: cache, favorites: favorites, now: { now }),
            getHistory: GetPriceHistory(cache: cache, backfill: BackfillHistory(remote: remote, cache: cache, now: { now }),
                                        now: { now }),
            toggleFavorite: ToggleFavorite(favorites: favorites),
            observeSettings: ObserveSettings(settings: self.settings),
            locateUser: LocateUser(location: FakeLocation(), firstFixTimeout: .milliseconds(100)),
            format: DisplayFormat(locale: Locale(identifier: "es_ES")),
            now: { now }
        )
    }

    func waitUntil(_ condition: @MainActor (StationDetailViewModel) -> Bool) async {
        for _ in 0..<200 {
            if condition(viewModel) { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// Everything a FavoritesViewModel needs, with handles on the fakes.
@MainActor
struct FavoritesHarness {
    let remote: FakeRemote
    let cache: FakeCache
    let favorites = FakeFavorites()
    let viewModel: FavoritesViewModel

    /// `remote` stations are what a province fetch returns; `cached` are there from the start.
    init(cached: [Station] = [], remote stations: [Station] = []) {
        let now = ListHarness.now
        let madrid = ProvinceID("28")
        remote = FakeRemote(snapshots: [madrid: ProvinceSnapshot(provinceID: madrid, stations: stations, snapshotDate: now)])
        cache = FakeCache(stored: cached.isEmpty ? [:] : [madrid: cached],
                          freshness: cached.isEmpty ? [:] : [madrid: Freshness(snapshotDate: now, fetchedAt: now)])
        let settings = FakeSettings()
        viewModel = FavoritesViewModel(
            observeFavorites: ObserveFavorites(favorites: favorites, cache: cache, now: { now }),
            toggleFavorite: ToggleFavorite(favorites: favorites),
            reorderFavorites: ReorderFavorites(favorites: favorites),
            observeICloudStatus: ObserveICloudStatus(favorites: favorites),
            refreshPrices: RefreshPrices(remote: remote, cache: cache, now: { now }),
            refreshFavorites: RefreshFavorites(refreshPrices: RefreshPrices(remote: remote, cache: cache, now: { now }),
                                               backfill: BackfillHistory(remote: remote, cache: cache, now: { now })),
            observeSettings: ObserveSettings(settings: settings),
            locateUser: LocateUser(location: FakeLocation(), firstFixTimeout: .milliseconds(100)),
            format: DisplayFormat(locale: Locale(identifier: "es_ES")),
            now: { now }
        )
    }

    func waitUntil(_ condition: @MainActor (FavoritesViewModel) -> Bool) async {
        for _ in 0..<200 {
            if condition(viewModel) { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// Everything a SearchViewModel needs, with handles on the fakes.
@MainActor
struct SearchHarness {
    let remote: FakeRemote
    let cache: FakeCache
    let favorites = FakeFavorites()
    let viewModel: SearchViewModel

    init(cached: [Station], remoteError: DomainError? = nil, location: FakeLocation = FakeLocation()) {
        let now = ListHarness.now
        let madrid = ProvinceID("28")
        remote = FakeRemote(error: remoteError)
        cache = FakeCache(stored: cached.isEmpty ? [:] : [madrid: cached],
                          freshness: cached.isEmpty ? [:] : [madrid: Freshness(snapshotDate: now, fetchedAt: now)])
        let settings = FakeSettings()
        viewModel = SearchViewModel(
            searchStations: SearchStations(cache: cache, provinces: FakeProvinces(), favorites: favorites,
                                           refreshPrices: RefreshPrices(remote: remote, cache: cache, now: { now }), now: { now }),
            resolveArea: ResolveArea(provinces: FakeProvinces()),
            toggleFavorite: ToggleFavorite(favorites: favorites),
            observeSettings: ObserveSettings(settings: settings),
            locateUser: LocateUser(location: location, firstFixTimeout: .milliseconds(100)),
            format: DisplayFormat(locale: Locale(identifier: "es_ES")),
            debounce: .zero,
            now: { now }
        )
    }

    func waitUntil(_ condition: @MainActor (SearchViewModel) -> Bool) async {
        for _ in 0..<200 {
            if condition(viewModel) { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

extension Fixtures {
    static func branded(_ id: String, _ name: String, diesel: String, metersNorth: Double = 500,
                        postcode: String = "28001") -> Station {
        let base = station(id, diesel: diesel, metersNorth: metersNorth)
        return Station(id: base.id, name: name,
                       address: Address(street: base.address.street, postcode: postcode, locality: "Madrid",
                                        municipality: "Madrid", province: "Madrid"),
                       coordinate: base.coordinate, roadSide: .notApplicable, hours: base.hours,
                       provinceID: base.provinceID, municipalityID: base.municipalityID, prices: base.prices)
    }
}
