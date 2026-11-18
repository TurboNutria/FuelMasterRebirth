import DomainLayer
import Foundation
import Testing
import ViewModelLayer

@Suite("Tent board view model")
@MainActor
struct TentBoardViewModelTests {
    let now = ListHarness.now

    func station(hours: OpeningHours = OpeningHours(rawText: "L-D: 24H", schedule: .alwaysOpen)) -> Station {
        let base = Fixtures.station("1", diesel: "1.459", hours: hours)
        var prices = base.prices
        prices[.petrol98E5] = Price(amount: Decimal(string: "1.689")!, product: .petrol98E5)
        prices[.lpg] = Price(amount: Decimal(string: "0.899")!, product: .lpg)
        return Station(id: base.id, name: base.name, address: base.address, coordinate: base.coordinate,
                       roadSide: .notApplicable, hours: base.hours, provinceID: base.provinceID,
                       municipalityID: base.municipalityID, prices: prices)
    }

    func viewModel(_ cache: FakeCache) -> TentBoardViewModel {
        let now = self.now
        return TentBoardViewModel(
            getDetail: GetStationDetail(cache: cache, favorites: FakeFavorites(), now: { now }),
            getHistory: GetPriceHistory(cache: cache, backfill: BackfillHistory(remote: FakeRemote(), cache: cache, now: { now }),
                                        now: { now }),
            backfillHistory: BackfillHistory(remote: FakeRemote(), cache: cache, now: { now }),
            format: DisplayFormat(locale: Locale(identifier: "es_ES")),
            now: { now }
        )
    }

    @Test func chosenFuelFirstThenTheSignOrderUpToThree() {
        let products = TentBoardViewModel.products(for: station(), chosen: .lpg)
        // Fixture prices: diesel, petrol 95 E5, plus 98 E5 and LPG added above.
        #expect(products == [.lpg, .diesel, .petrol95E5])
        #expect(TentBoardViewModel.products(for: station(), chosen: .diesel) == [.diesel, .petrol95E5, .petrol98E5])
        #expect(TentBoardViewModel.products(for: station(), chosen: .adBlue) == [.diesel, .petrol95E5, .petrol98E5])
    }

    @Test func rowsCarryTodayAgainstYesterday() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        let cache = FakeCache(stored: [ProvinceID("28"): [station()]],
                              freshness: [ProvinceID("28"): Freshness(snapshotDate: now, fetchedAt: now)])
        await cache.setHistory([HistoryPoint(day: yesterday, amount: Decimal(string: "1.467"))], for: .diesel)
        let board = viewModel(cache)

        let task = Task { await board.show(StationID("1"), product: .diesel, tankSize: 55) }
        for _ in 0..<200 where board.content?.rows.first?.change == nil { try? await Task.sleep(for: .milliseconds(10)) }

        let content = try #require(board.content)
        #expect(content.rows.map(\.product) == [.diesel, .petrol95E5, .petrol98E5])
        #expect(content.rows.first?.change?.difference == Decimal(string: "-0.008"))
        #expect(content.rows[1].change == nil)
        #expect(!content.isClosed)
        task.cancel()
    }

    @Test func closedStationKnowsWhenItOpens() async throws {
        let hours = OpeningHours(rawText: "L-D: 06:00-22:00",
                                 schedule: .weekly([DayRule(days: Set(Weekday.allCases), ranges: [TimeRange(start: 360, end: 1320)])]))
        let cache = FakeCache(stored: [ProvinceID("28"): [station(hours: hours)]],
                              freshness: [ProvinceID("28"): Freshness(snapshotDate: now, fetchedAt: now)])
        let board = viewModel(cache)
        let task = Task { await board.show(StationID("1"), product: .diesel, tankSize: 55) }
        for _ in 0..<200 where board.content == nil { try? await Task.sleep(for: .milliseconds(10)) }

        // ListHarness.now is 22:30 in Madrid.
        let content = try #require(board.content)
        #expect(content.isClosed)
        #expect(content.opensAt != nil)
        task.cancel()
    }
}
