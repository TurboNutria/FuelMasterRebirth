import DomainLayer
import Foundation
import Testing

@Suite("Refresh and history")
struct RefreshTests {
    let now = Fixtures.date(2026, 10, 21, 12, 0)
    let madrid = ProvinceID("28"), toledo = ProvinceID("45")

    @Test func fetchesOnlyStaleOrMissingProvinces() async {
        let snapshot = ProvinceSnapshot(provinceID: madrid, stations: [Fixtures.station("1", diesel: "1.859")], snapshotDate: now)
        let remote = FakeRemote(snapshots: [madrid: snapshot])
        let cache = FakeCache(freshness: [
            madrid: Freshness(snapshotDate: now, fetchedAt: now.addingTimeInterval(-31 * 60)), // stale
            toledo: Freshness(snapshotDate: now, fetchedAt: now.addingTimeInterval(-5 * 60)),  // fresh
        ])
        let widgets = FakeWidgets()
        let moment = now
        let outcome = await RefreshPrices(remote: remote, cache: cache, widgets: widgets, now: { moment })([madrid, toledo])

        #expect(outcome.updated == [madrid])
        #expect(outcome.skipped == [toledo])
        #expect(await remote.requestedProvinces == [madrid])
        #expect(widgets.reloads == 1)
    }

    @Test func reportsOfflineWithoutTouchingTheCache() async throws {
        let remote = FakeRemote(errors: [madrid: .offline])
        let cache = FakeCache(stored: [madrid: [Fixtures.station("1", diesel: "1.859")]])
        let outcome = await RefreshPrices(remote: remote, cache: cache)([madrid])

        #expect(outcome.isOffline)
        #expect(try await cache.stations(in: [madrid]).count == 1)
    }

    @Test func backfillFetchesOnlyMissingDaysOfTheLastWeek() async throws {
        let moment = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Fixtures.madrid
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let cache = FakeCache(knownDays: [yesterday])
        let remote = FakeRemote()
        let backfill = BackfillHistory(remote: remote, cache: cache, now: { moment })

        #expect(backfill.window().count == 7)
        #expect(backfill.window().last == yesterday)
        #expect(try await backfill(province: madrid, product: .diesel) == 6)
        #expect(await !remote.requestedDays.contains(yesterday))
    }
}

@Suite("Nearby stations")
struct NearbyTests {
    let sol = Coordinate(latitude: 40.4169, longitude: -3.7035)

    @Test func filtersByRadiusSortsByPriceAndMarksFavorites() async throws {
        let near = Coordinate(latitude: 40.4102, longitude: -3.7175)   // ≈ 1,4 km
        let far = Coordinate(latitude: 40.5300, longitude: -3.4800)    // ≈ 23 km
        let stations = [
            Fixtures.station("A", diesel: "1.929", at: near),
            Fixtures.station("B", diesel: "1.859", at: near),
            Fixtures.station("C", diesel: "1.700", at: far),
        ]
        let observe = ObserveNearbyStations(cache: FakeCache(stored: [ProvinceID("28"): stations]), favorites: FakeFavorites(["B"]))
        let request = NearbyRequest(provinces: [ProvinceID("28")], area: .radius(center: sol, meters: 3000),
                                    product: .diesel, origin: sol)
        let result = try await observe.load(request)

        #expect(result.stations.map(\.id.rawValue) == ["B", "A"])
        #expect(result.stations.first?.isFavorite == true)
        // The far station still counts towards the area average.
        #expect(result.summary?.stationCount == 3)
    }

    @Test func levelFilterKeepsOnlyCheapStations() async throws {
        let stations = [
            Fixtures.station("cheap", diesel: "1.800"),
            Fixtures.station("mid", diesel: "1.900"),
            Fixtures.station("dear", diesel: "2.000"),
        ]
        let observe = ObserveNearbyStations(cache: FakeCache(stored: [ProvinceID("28"): stations]), favorites: FakeFavorites())
        let request = NearbyRequest(provinces: [ProvinceID("28")], area: .radius(center: sol, meters: 1000),
                                    product: .diesel, levels: [.cheap])
        #expect(try await observe.load(request).stations.map(\.id.rawValue) == ["cheap"])
    }
}
