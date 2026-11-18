import DomainLayer
import Foundation
import Testing
import ViewModelLayer

@Suite("Station detail view model")
@MainActor
struct StationDetailViewModelTests {
    let stations = [Fixtures.station("1", diesel: "1.859", metersNorth: 1400),
                    Fixtures.station("2", diesel: "1.954"), Fixtures.station("3", diesel: "1.959")]

    @Test func showsPriceTankDistanceAndChart() async throws {
        let harness = DetailHarness(stations: stations)
        let task = Task { await harness.viewModel.show(StationID("1")) }
        await harness.waitUntil { $0.state.content?.detail.distance != nil && $0.state.content?.chart?.isLoading == false }

        let content = try #require(harness.viewModel.state.content)
        #expect(content.detail.level == .cheap)
        #expect(content.detail.fuelCost?.amount == Decimal(string: "102.25"))
        #expect(content.detail.tankSaving == Decimal(string: "3.58"))
        #expect(content.hours.today == .allDay)
        #expect(abs((content.detail.distance ?? 0) - 1400) < 20)
        let chart = try #require(content.chart)
        #expect(chart.history.points.count == 7)
        #expect(chart.history.points.last?.amount == Decimal(string: "1.859"))
        // A flat week still gets a 6-cent tall chart.
        #expect(chart.range.upperBound - chart.range.lowerBound >= 0.06)
        #expect(!chart.isIncomplete)
        #expect(harness.viewModel.shareURL?.absoluteString.contains("maps.apple.com") == true)
        task.cancel()
    }

    @Test func unknownStationFails() async {
        let harness = DetailHarness(stations: stations)
        let task = Task { await harness.viewModel.show(StationID("99")) }
        await harness.waitUntil { $0.state != .firstLoad }
        #expect(harness.viewModel.state == .failed(.notFound))
        task.cancel()
    }

    @Test func offlineHistoryKeepsTodayAndFlagsIncomplete() async throws {
        let harness = DetailHarness(stations: stations, remoteError: .offline)
        let task = Task { await harness.viewModel.show(StationID("1")) }
        await harness.waitUntil { $0.state.content?.chart?.isIncomplete == true }

        let chart = try #require(harness.viewModel.state.content?.chart)
        #expect(chart.isIncomplete)
        #expect(chart.history.points.last?.amount != nil)
        task.cancel()
    }

    @Test func favouriteToggleIsImmediateAndStored() async throws {
        let harness = DetailHarness(stations: stations)
        let task = Task { await harness.viewModel.show(StationID("1")) }
        await harness.waitUntil { $0.state.content != nil }
        #expect(harness.viewModel.state.content?.isFavorite == false)

        await harness.viewModel.toggleFavorite()
        #expect(harness.viewModel.state.content?.isFavorite == true)
        #expect(try await harness.favorites.favorites().map(\.stationID) == [StationID("1")])
        await harness.waitUntil { $0.state.content?.detail.isFavorite == true }
        #expect(harness.viewModel.state.content?.detail.isFavorite == true)

        await harness.viewModel.toggleFavorite()
        #expect(harness.viewModel.state.content?.isFavorite == false)
        task.cancel()
    }

    @Test func fuelChangeInSettingsFollows() async throws {
        let harness = DetailHarness(stations: stations)
        let task = Task { await harness.viewModel.show(StationID("1")) }
        await harness.waitUntil { $0.state.content != nil }

        await UpdateSettings(settings: harness.settings) { $0.product = .petrol95E5 }
        await harness.waitUntil { $0.state.content?.product == .petrol95E5 }

        let content = try #require(harness.viewModel.state.content)
        #expect(content.detail.price?.amount == Decimal(string: "1.700"))
        #expect(content.detail.otherPrices.map(\.product) == [.diesel])
        task.cancel()
    }

    @Test func switchingStationsResetsState() async throws {
        let harness = DetailHarness(stations: stations)
        let first = Task { await harness.viewModel.show(StationID("1")) }
        await harness.waitUntil { $0.state.content?.station.id == StationID("1") }
        first.cancel()

        let second = Task { await harness.viewModel.show(StationID("2")) }
        await harness.waitUntil { $0.state.content?.station.id == StationID("2") }
        #expect(harness.viewModel.state.content?.detail.level == .average)
        second.cancel()
    }

    /// Found on the simulator: on a cold cache the station only appears once its province loads,
    /// and the chart has to follow.
    @Test func historyLoadsOnceTheStationArrives() async throws {
        let harness = DetailHarness(stations: [])
        let task = Task { await harness.viewModel.show(StationID("1")) }
        await harness.waitUntil { $0.state != .firstLoad }
        #expect(harness.viewModel.state == .failed(.notFound))

        try await harness.cache.save(ProvinceSnapshot(provinceID: ProvinceID("28"), stations: stations,
                                                      snapshotDate: ListHarness.now), fetchedAt: ListHarness.now)
        await harness.waitUntil { $0.state.content?.chart?.isLoading == false }

        let chart = try #require(harness.viewModel.state.content?.chart)
        #expect(chart.history.points.last?.amount == Decimal(string: "1.859"))
        task.cancel()
    }

    /// Found on the iPad: at launch the tabs push and the inspector overlap, and the newer one
    /// leaves first. The detail must keep updating for the one still on screen.
    @Test func overlappingScreensKeepTheDetailAlive() async throws {
        let harness = DetailHarness(stations: [])
        let survivor = Task { await harness.viewModel.show(StationID("1")) }
        let transient = Task { await harness.viewModel.show(StationID("1")) }
        await harness.waitUntil { $0.state != .firstLoad }
        transient.cancel()
        await transient.value

        try await harness.cache.save(ProvinceSnapshot(provinceID: ProvinceID("28"), stations: stations,
                                                      snapshotDate: ListHarness.now), fetchedAt: ListHarness.now)
        await harness.waitUntil { $0.state.content != nil }
        #expect(harness.viewModel.state.content?.station.id == StationID("1"))
        survivor.cancel()
    }
}
