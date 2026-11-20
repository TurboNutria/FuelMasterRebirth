import DomainLayer
import Foundation
import Testing
import ViewModelLayer

@Suite("Watch station detail view model")
@MainActor
struct WatchStationDetailViewModelTests {
    let stations = [Fixtures.station("1", diesel: "1.859", metersNorth: 1400),
                    Fixtures.station("2", diesel: "1.954"), Fixtures.station("3", diesel: "1.959")]

    @Test func showsPriceGapHoursAndDistance() async throws {
        let harness = WatchDetailHarness(stations: stations)
        let task = Task { await harness.viewModel.show(StationID("1")) }
        await harness.waitUntil { $0.state.content?.detail.distance != nil }

        let content = try #require(harness.viewModel.state.content)
        #expect(content.detail.price?.amount == Decimal(string: "1.859"))
        #expect(content.detail.level == .cheap)
        #expect((content.detail.belowAverage ?? 0) > 0)
        #expect(content.hours.today == .allDay)
        #expect(abs((content.detail.distance ?? 0) - 1400) < 20)
        // Opening the detail on the watch never downloads history.
        #expect(await harness.remote.calls == 0)
        task.cancel()
    }

    @Test func unknownStationFails() async {
        let harness = WatchDetailHarness(stations: stations)
        let task = Task { await harness.viewModel.show(StationID("99")) }
        await harness.waitUntil { $0.state != .firstLoad }
        #expect(harness.viewModel.state == .failed(.notFound))
        task.cancel()
    }

    @Test func favouriteToggleIsImmediateAndStored() async throws {
        let harness = WatchDetailHarness(stations: stations)
        let task = Task { await harness.viewModel.show(StationID("1")) }
        await harness.waitUntil { $0.state.content != nil }

        await harness.viewModel.toggleFavorite()
        #expect(harness.viewModel.state.content?.isFavorite == true)
        #expect(try await harness.favorites.favorites().map(\.stationID) == [StationID("1")])
        await harness.waitUntil { $0.state.content?.detail.isFavorite == true }

        await harness.viewModel.toggleFavorite()
        #expect(harness.viewModel.state.content?.isFavorite == false)
        task.cancel()
    }

    @Test func followsAFuelChange() async throws {
        let harness = WatchDetailHarness(stations: stations)
        let task = Task { await harness.viewModel.show(StationID("1")) }
        await harness.waitUntil { $0.state.content != nil }

        await UpdateSettings(settings: harness.settings) { $0.product = .petrol95E5 }
        await harness.waitUntil { $0.state.content?.product == .petrol95E5 }
        #expect(harness.viewModel.state.content?.detail.price?.amount == Decimal(string: "1.700"))
        task.cancel()
    }
}

@Suite("Stale age")
struct StaleAgeTests {
    let format = DisplayFormat(locale: Locale(identifier: "es_ES"))
    let now = Fixtures.date(2026, 10, 20, 22, 30)

    @Test func freshPricesShowNoAge() {
        #expect(StaleAge.text(pricesDate: now.addingTimeInterval(-50 * 60), now: now, format: format) == nil)
        #expect(StaleAge.text(pricesDate: nil, now: now, format: format) == nil)
    }

    @Test func oldPricesShowTheirAge() {
        #expect(StaleAge.text(pricesDate: now.addingTimeInterval(-3 * 60 * 60), now: now, format: format) == "Hace 3 h")
    }
}

@MainActor
struct WatchDetailHarness {
    let remote = FakeRemote()
    let cache: FakeCache
    let favorites = FakeFavorites()
    let settings = FakeSettings()
    let viewModel: WatchStationDetailViewModel

    init(stations: [Station]) {
        let now = ListHarness.now
        cache = FakeCache(stored: [ProvinceID("28"): stations],
                          freshness: [ProvinceID("28"): Freshness(snapshotDate: now.addingTimeInterval(-12 * 60), fetchedAt: now)])
        viewModel = WatchStationDetailViewModel(
            getDetail: GetStationDetail(cache: cache, favorites: favorites, now: { now }),
            toggleFavorite: ToggleFavorite(favorites: favorites),
            observeSettings: ObserveSettings(settings: settings),
            locateUser: LocateUser(location: FakeLocation(), firstFixTimeout: .milliseconds(100)),
            format: DisplayFormat(locale: Locale(identifier: "es_ES")),
            now: { now }
        )
    }

    func waitUntil(_ condition: @MainActor (WatchStationDetailViewModel) -> Bool) async {
        for _ in 0..<200 {
            if condition(viewModel) { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
