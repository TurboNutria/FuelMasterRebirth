import DomainLayer
import Foundation
import Testing

private let madrid = ProvinceID("28")
private let toledo = ProvinceID("45")
private let sol = Coordinate(latitude: 40.4169, longitude: -3.7035)

private actor MemorySettings: SettingsRepository {
    private(set) var settings: Settings
    private(set) var writes = 0
    init(_ settings: Settings = .default) { self.settings = settings }
    func current() async -> Settings { settings }
    @discardableResult
    func update(_ change: @Sendable (inout Settings) -> Void) async -> Settings {
        change(&settings)
        writes += 1
        return settings
    }
    func changes() async -> AsyncStream<Settings> { AsyncStream { $0.finish() } }
}

private struct TwoProvinces: ProvinceRepository {
    static let madridProvince = Province(
        id: madrid, name: "Madrid", regionID: "13",
        bounds: BoundingBox(minLatitude: 39.8, minLongitude: -4.6, maxLatitude: 41.2, maxLongitude: -3.0),
        outline: [], samples: []
    )
    func allProvinces() async -> [Province] { [Self.madridProvince] }
    func province(at coordinate: Coordinate) async -> ProvinceID? { madrid }
    func provinces(intersecting bounds: BoundingBox) async -> [ProvinceID] { [madrid] }
    func municipalities(matching text: String) async -> [Municipality] { [] }
}

private func station(_ id: String, _ diesel: String, metersNorth: Double, province: String = "28") -> Station {
    Fixtures.named(id, "Station \(id)", diesel: diesel, province: province, metersNorth: metersNorth)
}

@Suite("Widgets and background refresh")
struct WidgetTests {
    let now = Fixtures.date(2026, 11, 18, 10, 0)

    private func snapshot(stations: [Station], favorites: [String] = [], settings: Settings) async -> WidgetSnapshot {
        let fresh = Freshness(snapshotDate: now.addingTimeInterval(-600), fetchedAt: now.addingTimeInterval(-300))
        let cache = FakeCache(stored: [madrid: stations], freshness: [madrid: fresh])
        let favoriteStore = FakeFavorites(favorites)
        let now = self.now
        let use = GetWidgetSnapshot(
            settings: MemorySettings(settings), provinces: TwoProvinces(),
            nearby: ObserveNearbyStations(cache: cache, favorites: favoriteStore, now: { now }),
            favorites: ObserveFavorites(favorites: favoriteStore, cache: cache, now: { now })
        )
        return await use()
    }

    @Test("Cheapest within 3 km of the last location, with its distance")
    func cheapestNearLastLocation() async {
        var settings = Settings.default
        settings.lastLocation = sol
        let result = await snapshot(stations: [
            station("1", "1.899", metersNorth: 500),
            station("2", "1.859", metersNorth: 1400),
            station("3", "1.799", metersNorth: 9000), // cheaper but outside the radius
        ], settings: settings)
        #expect(result.cheapest?.station.id == StationID("2"))
        #expect(result.cheapest.flatMap(\.distance).map { abs($0 - 1400) < 20 } == true)
        #expect(result.summary?.minimum == Decimal(string: "1.799"))
        #expect(result.freshness != nil)
    }

    @Test("Nothing within 3 km: the nearest station within 25 km")
    func nearestWhenRadiusIsEmpty() async {
        var settings = Settings.default
        settings.lastLocation = sol
        let result = await snapshot(stations: [
            station("1", "1.799", metersNorth: 20_000),
            station("2", "1.899", metersNorth: 8000),
        ], settings: settings)
        #expect(result.cheapest?.station.id == StationID("2"))
    }

    @Test("No location: the cheapest in the default province, without a distance")
    func cheapestInProvince() async {
        var settings = Settings.default
        settings.defaultProvinceID = madrid
        let result = await snapshot(stations: [
            station("1", "1.899", metersNorth: 500),
            station("2", "1.799", metersNorth: 30_000),
        ], settings: settings)
        #expect(result.cheapest?.station.id == StationID("2"))
        #expect(result.cheapest?.distance == nil)
    }

    @Test("Favourites keep their order and drop those without the fuel")
    func favoritesInOrder() async {
        var settings = Settings.default
        settings.lastLocation = sol
        let noDiesel = Fixtures.station("9", diesel: nil)
        let result = await snapshot(stations: [
            station("1", "1.899", metersNorth: 500), station("2", "1.859", metersNorth: 900), noDiesel,
        ], favorites: ["2", "9", "1"], settings: settings)
        #expect(result.favorites.map(\.id) == [StationID("2"), StationID("1")])
        #expect(result.favoritesFreshness != nil)
    }

    @Test("Empty cache: no station and no freshness")
    func emptyCache() async {
        let cache = FakeCache()
        let favorites = FakeFavorites()
        let use = GetWidgetSnapshot(settings: MemorySettings(), provinces: TwoProvinces(),
                                    nearby: ObserveNearbyStations(cache: cache, favorites: favorites),
                                    favorites: ObserveFavorites(favorites: favorites, cache: cache))
        let result = await use()
        #expect(result.cheapest == nil)
        #expect(result.freshness == nil)
        #expect(result.favorites.isEmpty)
    }

    @Test("Remembering the area stores the position and province, ignoring small moves")
    func rememberArea() async {
        let settings = MemorySettings()
        let remember = RememberArea(settings: settings, provinces: TwoProvinces())
        await remember(sol)
        #expect(await settings.settings.lastLocation == sol)
        #expect(await settings.settings.lastViewedProvinceID == madrid)
        await remember(Coordinate(latitude: sol.latitude + 200 / 111_000, longitude: sol.longitude))
        #expect(await settings.writes == 1)
        let farther = Coordinate(latitude: sol.latitude + 2000 / 111_000, longitude: sol.longitude)
        await remember(farther)
        #expect(await settings.writes == 2)
        #expect(await settings.settings.lastLocation == farther)
    }

    @Test("Background refresh covers the last area and the favourites' provinces, skipping fresh ones")
    func backgroundRefresh() async {
        var stored = Settings.default
        stored.lastLocation = sol
        let fresh = Freshness(snapshotDate: now, fetchedAt: now.addingTimeInterval(-5 * 60))
        let cache = FakeCache(freshness: [toledo: fresh])
        let remote = FakeRemote(snapshots: [madrid: ProvinceSnapshot(provinceID: madrid, stations: [], snapshotDate: now)])
        let favorites = FakeFavorites()
        try? await favorites.add(StationID("7"), province: toledo)
        let widgets = FakeWidgets()
        let now = self.now
        let refresh = RefreshInBackground(
            settings: MemorySettings(stored), provinces: TwoProvinces(), favorites: favorites,
            refreshPrices: RefreshPrices(remote: remote, cache: cache, widgets: widgets, now: { now })
        )
        #expect(await refresh.provinces() == [madrid, toledo])
        let outcome = await refresh()
        #expect(outcome.updated == [madrid])
        #expect(outcome.skipped == [toledo])
        #expect(await remote.requestedProvinces == [madrid])
        #expect(widgets.reloads == 1)
    }

    @Test("Background refresh without a location uses the default province")
    func backgroundRefreshDefaultProvince() async {
        var stored = Settings.default
        stored.defaultProvinceID = madrid
        let cache = FakeCache()
        let refresh = RefreshInBackground(
            settings: MemorySettings(stored), provinces: TwoProvinces(), favorites: FakeFavorites(),
            refreshPrices: RefreshPrices(remote: FakeRemote(), cache: cache)
        )
        #expect(await refresh.provinces() == [madrid])
    }
}

@Suite("Area to show")
struct ResolveAreaTests {
    let resolve = ResolveArea(provinces: TwoProvinces())

    @Test("Without a position: the default province, then the last viewed one, then Madrid")
    func provinceFallsBackInOrder() {
        var settings = Settings.default
        #expect(ResolveArea.province(for: settings) == ResolveArea.fallbackProvince)
        settings.lastViewedProvinceID = toledo
        #expect(ResolveArea.province(for: settings) == toledo)
        settings.defaultProvinceID = madrid
        #expect(ResolveArea.province(for: settings) == madrid)
    }

    @Test("A position gives the list radius around it")
    func aroundAPosition() async {
        let area = await resolve(around: sol)
        #expect(area.area == .radius(center: sol, meters: ResolveArea.radius))
        #expect(area.origin == sol)
        #expect(area.provinces == [madrid])
        #expect(area.provinceName == nil)
    }

    @Test("A province gives its bounds and name; an unknown one gives nothing")
    func wholeProvince() async {
        let area = await resolve(province: madrid)
        #expect(area?.area == .bounds(TwoProvinces.madridProvince.bounds))
        #expect(area?.provinceName == "Madrid")
        #expect(area?.origin == nil)
        #expect(await resolve(province: ProvinceID("99")) == nil)
    }

    @Test("From the settings: the last position wins over the province")
    func fromSettings() async {
        var settings = Settings.default
        settings.defaultProvinceID = madrid
        #expect(await resolve(settings)?.origin == nil)
        settings.lastLocation = sol
        #expect(await resolve(settings)?.origin == sol)
    }
}
