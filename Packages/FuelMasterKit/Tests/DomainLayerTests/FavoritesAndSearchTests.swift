import DomainLayer
import Foundation
import Testing

@Suite("Favourites and search")
struct FavoritesAndSearchTests {
    let now = Fixtures.date(2026, 10, 20, 22, 30)
    let madrid = ProvinceID("28"), toledo = ProvinceID("45")

    var yesterday: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Fixtures.madrid
        return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
    }

    @Test func favouritesKeepTheirOrderWithCheapestAndChange() async throws {
        let moment = now
        let cache = FakeCache(stored: [madrid: [Fixtures.named("1", "Ballenoil", diesel: "1.859"),
                                                Fixtures.named("2", "Shell", diesel: "1.934"),
                                                Fixtures.named("3", "Repsol", diesel: "2.019")]],
                              freshness: [madrid: Freshness(snapshotDate: now, fetchedAt: now)])
        await cache.setHistory([HistoryPoint(day: yesterday, amount: Decimal(string: "1.939"))], area: [])
        let favorites = FakeFavorites(["3", "1", "2", "9"])
        let result = try await ObserveFavorites(favorites: favorites, cache: cache, now: { moment })
            .load(FavoritesRequest(product: .diesel, tankSize: 55))

        #expect(result.items.map(\.id.rawValue) == ["3", "1", "2", "9"])
        #expect(result.items[3].station == nil)
        #expect(result.best?.summary.id == StationID("1"))
        #expect(result.best?.fuelCost?.amount == Decimal(string: "102.25"))
        // The fake history is the same for every station: 1,939 yesterday.
        #expect(result.items[2].change?.direction == .down)
        #expect(result.items[2].change?.difference == Decimal(string: "-0.005"))
        #expect(result.missingProvinces.isEmpty)
    }

    @Test func favouriteInAnUnloadedProvinceIsReportedMissing() async throws {
        let cache = FakeCache()
        let favorites = FakeFavorites()
        try await favorites.add(StationID("7"), province: toledo)
        let result = try await ObserveFavorites(favorites: favorites, cache: cache)
            .load(FavoritesRequest(product: .diesel, tankSize: 55))
        #expect(result.missingProvinces == [toledo])
        #expect(result.best == nil)
    }

    func search(_ text: String, _ scope: SearchScope = .all, cache: FakeCache, remote: FakeRemote = FakeRemote(),
                municipalities: [Municipality] = []) async throws -> SearchResult {
        let moment = now
        return try await SearchStations(cache: cache, provinces: FakeProvinces(municipalities: municipalities), favorites: FakeFavorites(["2"]),
                                        refreshPrices: RefreshPrices(remote: remote, cache: cache, now: { moment }),
                                        now: { moment })(SearchQuery(text: text, scope: scope), product: .diesel,
                                                         area: [madrid], origin: Coordinate(latitude: 40.4169, longitude: -3.7035))
    }

    func madridCache() -> FakeCache {
        FakeCache(stored: [madrid: [Fixtures.named("1", "Repsol", diesel: "1.969", metersNorth: 1600),
                                    Fixtures.named("2", "REPSOL", diesel: "1.999", metersNorth: 1400),
                                    Fixtures.named("3", "Shell", diesel: "1.934", locality: "Alcobendas", postcode: "28100")]],
                  freshness: [madrid: Freshness(snapshotDate: now, fetchedAt: now)])
    }

    @Test func brandMatchesIgnoringCaseNearestFirst() async throws {
        let result = try await search("repsol", .brand, cache: madridCache())
        #expect(result.hits.map(\.id.rawValue) == ["2", "1"])
        #expect(result.hits.allSatisfy { $0.match == .name })
        #expect(result.hits.first?.summary.isFavorite == true)
        #expect(result.sortedByDistance)
    }

    @Test func digitsInTodoSearchPostcodes() async throws {
        let result = try await search("28100", cache: madridCache())
        #expect(result.hits.map(\.id.rawValue) == ["3"])
        #expect(result.hits.first?.match == .postcode)
        #expect(try await search("28999", cache: madridCache()).hits.isEmpty)
    }

    @Test func localityIgnoresAccentsAndLoadsItsProvince() async throws {
        let cache = FakeCache()
        let toledoStation = Fixtures.named("8", "Cepsa", diesel: "1.799", locality: "Talavera de la Reina",
                                           postcode: "45600", province: "45")
        let remote = FakeRemote(snapshots: [toledo: ProvinceSnapshot(provinceID: toledo, stations: [toledoStation], snapshotDate: now)])
        let result = try await search("TALAVERA", .locality, cache: cache, remote: remote,
                                      municipalities: [Municipality(id: MunicipalityID("4565"), name: "Talavera de la Reina",
                                                                    provinceID: toledo)])
        #expect(result.hits.map(\.id.rawValue) == ["8"])
        #expect(result.hits.first?.match == .locality)
        #expect(await remote.requestedProvinces.contains(toledo))
    }

    @Test func offlineSearchWithNothingCachedReportsIt() async throws {
        let remote = FakeRemote(errors: [ProvinceID("45"): .offline])
        let result = try await search("45600", cache: FakeCache(), remote: remote)
        #expect(result.hits.isEmpty)
        #expect(result.loadFailure == .offline)
    }

    @Test func backfillCanFetchJustYesterday() async throws {
        let moment = now
        let cache = FakeCache(), remote = FakeRemote()
        try await BackfillHistory(remote: remote, cache: cache, now: { moment })(province: madrid, product: .diesel, recentDays: 1)
        #expect(await remote.requestedDays == [yesterday])
    }
}
