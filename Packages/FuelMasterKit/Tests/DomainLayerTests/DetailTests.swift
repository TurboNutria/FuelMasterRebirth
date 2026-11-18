import DomainLayer
import Foundation
import Testing

@Suite("Station detail")
struct DetailTests {
    let now = Fixtures.date(2026, 10, 20, 22, 30)
    let madrid = ProvinceID("28")

    /// Ballenoil at 1,859 against stations averaging 1,924, as on the canvas.
    func cache() -> FakeCache {
        var cheap = Fixtures.station("1", diesel: "1.859")
        cheap = Station(id: cheap.id, name: cheap.name, address: cheap.address, coordinate: cheap.coordinate,
                        roadSide: cheap.roadSide, hours: cheap.hours, provinceID: cheap.provinceID,
                        municipalityID: cheap.municipalityID,
                        prices: [.diesel: Price(amount: Decimal(string: "1.859")!, product: .diesel),
                                 .petrol95E5: Price(amount: Decimal(string: "1.729")!, product: .petrol95E5),
                                 .adBlue: Price(amount: Decimal(string: "0.899")!, product: .adBlue)])
        return FakeCache(stored: [madrid: [cheap, Fixtures.station("2", diesel: "1.954"), Fixtures.station("3", diesel: "1.959")]],
                         freshness: [madrid: Freshness(snapshotDate: now, fetchedAt: now)])
    }

    @Test func priceAgainstTheProvinceAverageAndTankCost() async throws {
        let moment = now
        let detail = try #require(try await GetStationDetail(cache: cache(), favorites: FakeFavorites(["1"]), now: { moment })
            .load(StationDetailRequest(stationID: StationID("1"), product: .diesel, tankSize: 55)))

        #expect(detail.price?.amount == Decimal(string: "1.859"))
        #expect(detail.areaAverage == Decimal(string: "1.924"))
        #expect(detail.level == .cheap)
        #expect(detail.belowAverage == Decimal(string: "0.065"))
        #expect(detail.fuelCost?.amount == Decimal(string: "102.25"))
        #expect(detail.tankSaving == Decimal(string: "3.58"))
        #expect(detail.isFavorite)
        // Other products in the picker's order: petrol before AdBlue.
        #expect(detail.otherPrices.map(\.product) == [.petrol95E5, .adBlue])
    }

    @Test func adBlueHasNoTankCostAndMissingProductHasNoPrice() async throws {
        let cache = cache()
        let adBlue = try #require(try await GetStationDetail(cache: cache, favorites: FakeFavorites())
            .load(StationDetailRequest(stationID: StationID("1"), product: .adBlue, tankSize: 55)))
        #expect(adBlue.price != nil)
        #expect(adBlue.fuelCost == nil)

        let lpg = try #require(try await GetStationDetail(cache: cache, favorites: FakeFavorites())
            .load(StationDetailRequest(stationID: StationID("1"), product: .lpg, tankSize: 55)))
        #expect(lpg.price == nil)
        #expect(lpg.level == nil)
        #expect(lpg.fuelCost == nil)
        #expect(lpg.otherPrices.count == 3)
    }

    @Test func unknownStationIsNil() async throws {
        let detail = try await GetStationDetail(cache: cache(), favorites: FakeFavorites())
            .load(StationDetailRequest(stationID: StationID("99"), product: .diesel, tankSize: 55))
        #expect(detail == nil)
    }

    @Test func historyEndsTodayWithCurrentPriceAndLeavesGaps() async throws {
        let moment = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Fixtures.madrid
        let today = calendar.startOfDay(for: now)
        let day = { (offset: Int) in calendar.date(byAdding: .day, value: -offset, to: today)! }
        let cache = cache()
        await cache.setHistory([HistoryPoint(day: day(6), amount: Decimal(string: "1.879")),
                                HistoryPoint(day: day(2), amount: Decimal(string: "1.869")),
                                HistoryPoint(day: day(9), amount: 2)],
                               area: [HistoryPoint(day: day(3), amount: Decimal(string: "1.928"))])
        let getHistory = GetPriceHistory(cache: cache, backfill: BackfillHistory(remote: FakeRemote(), cache: cache, now: { moment }),
                                         now: { moment })

        let history = try #require(try await getHistory.cached(station: StationID("1"), product: .diesel))

        #expect(history.points.count == 7)
        #expect(history.points.first?.day == day(6))
        #expect(history.points.last?.day == today)
        #expect(history.points.last?.amount == Decimal(string: "1.859"))
        #expect(history.points[1].amount == nil)
        #expect(history.areaAverage.last?.amount == Decimal(string: "1.924"))
        #expect(history.areaAverage[3].amount == Decimal(string: "1.928"))
        #expect(history.minimum == Decimal(string: "1.859"))
        #expect(history.change?.difference == Decimal(string: "-0.02"))
    }

    @Test func historyBackfillsMissingDaysFirst() async throws {
        let moment = now
        let cache = cache(), remote = FakeRemote()
        let getHistory = GetPriceHistory(cache: cache, backfill: BackfillHistory(remote: remote, cache: cache, now: { moment }),
                                         now: { moment })

        _ = try await getHistory(station: StationID("1"), product: .diesel)

        #expect(await remote.requestedDays.count == 7)
        #expect(await cache.savedHistory.count == 7)
    }

    @Test func toggleAddsThenRemoves() async throws {
        let favorites = FakeFavorites()
        let toggle = ToggleFavorite(favorites: favorites)

        #expect(try await toggle(StationID("1"), province: madrid))
        #expect(try await favorites.favorites().map(\.stationID) == [StationID("1")])
        #expect(try await !toggle(StationID("1"), province: madrid))
        #expect(try await favorites.favorites().isEmpty)
    }
}
