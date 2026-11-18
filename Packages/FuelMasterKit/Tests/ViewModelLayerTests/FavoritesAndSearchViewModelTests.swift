import DomainLayer
import Foundation
import Testing
import ViewModelLayer

@Suite("Favoritos view model")
@MainActor
struct FavoritesViewModelTests {
    let stations = [Fixtures.branded("1", "Ballenoil", diesel: "1.859"), Fixtures.branded("2", "Shell", diesel: "1.934"),
                    Fixtures.branded("3", "Shell", diesel: "1.939"), Fixtures.branded("4", "Repsol", diesel: "2.019")]

    func favourite(_ ids: [String], in harness: FavoritesHarness) async throws {
        for id in ids { try await harness.favorites.add(StationID(id), province: ProvinceID("28")) }
    }

    @Test func noFavouritesIsEmpty() async {
        let harness = FavoritesHarness(cached: stations)
        let task = Task { await harness.viewModel.start() }
        await harness.waitUntil { $0.state != .firstLoad }
        #expect(harness.viewModel.state == .empty(.noFavorites))
        task.cancel()
    }

    @Test func rowsKeepTheUsersOrderWithTheCheapest() async throws {
        let harness = FavoritesHarness(cached: stations)
        try await favourite(["4", "2", "1", "3"], in: harness)
        let task = Task { await harness.viewModel.start() }
        await harness.waitUntil { $0.state.content != nil }

        let content = try #require(harness.viewModel.state.content)
        #expect(content.rows.map(\.id.rawValue) == ["4", "2", "1", "3"])
        #expect(content.best?.summary.id == StationID("1"))
        #expect(content.best?.fuelCost?.amount == Decimal(string: "102.25"))
        #expect(content.rows.allSatisfy { $0.hours != nil })
        task.cancel()
    }

    @Test func favouriteInAnUnloadedProvinceLoadsIt() async throws {
        let harness = FavoritesHarness(remote: stations)
        try await favourite(["2"], in: harness)
        let task = Task { await harness.viewModel.start() }
        await harness.waitUntil { $0.state.content?.rows.first?.summary != nil }

        #expect(harness.viewModel.state.content?.rows.first?.summary?.price.amount == Decimal(string: "1.934"))
        #expect(await harness.remote.calls >= 1)
        task.cancel()
    }

    @Test func removeAndMoveShowAtOnceAndAreStored() async throws {
        let harness = FavoritesHarness(cached: stations)
        try await favourite(["1", "2", "4"], in: harness)
        let task = Task { await harness.viewModel.start() }
        await harness.waitUntil { $0.state.content?.rows.count == 3 }

        await harness.viewModel.move(from: 2, to: 0)
        #expect(harness.viewModel.state.content?.rows.map(\.id.rawValue) == ["4", "1", "2"])

        await harness.viewModel.remove(StationID("1"))
        // The move's own update can land just after this and is then corrected by the remove's.
        await harness.waitUntil { $0.state.content?.rows.map(\.id.rawValue) == ["4", "2"] }
        #expect(harness.viewModel.state.content?.rows.map(\.id.rawValue) == ["4", "2"])
        #expect(try await harness.favorites.favorites().map(\.stationID.rawValue).contains("1") == false)
        task.cancel()
    }
}

@Suite("Buscar view model")
@MainActor
struct SearchViewModelTests {
    let stations = [Fixtures.branded("1", "Repsol", diesel: "1.969", metersNorth: 1600),
                    Fixtures.branded("2", "Repsol", diesel: "1.999", metersNorth: 1400),
                    Fixtures.branded("3", "Shell", diesel: "1.934", postcode: "28100")]

    @Test func idleUntilSomethingIsTyped() async {
        let harness = SearchHarness(cached: stations)
        let task = Task { await harness.viewModel.start() }
        #expect(harness.viewModel.isIdle)
        task.cancel()
    }

    @Test func brandResultsNearestFirst() async throws {
        let harness = SearchHarness(cached: stations)
        let task = Task { await harness.viewModel.start() }
        harness.viewModel.text = "repsol"
        await harness.waitUntil { $0.state.content != nil }

        let content = try #require(harness.viewModel.state.content)
        #expect(content.rows.map(\.id.rawValue) == ["2", "1"])
        #expect(content.text == "repsol")
        #expect(content.sortedByDistance)
        task.cancel()
    }

    @Test func scopeChangeSearchesAgain() async throws {
        let harness = SearchHarness(cached: stations)
        let task = Task { await harness.viewModel.start() }
        harness.viewModel.text = "28100"
        await harness.waitUntil { $0.state.content != nil }
        #expect(harness.viewModel.state.content?.scope == .postcode)

        harness.viewModel.scope = .brand
        await harness.waitUntil { $0.state == .empty(.noSearchResults("28100")) }
        #expect(harness.viewModel.state == .empty(.noSearchResults("28100")))
        task.cancel()
    }

    @Test func clearingTheTextGoesBackToIdle() async {
        let harness = SearchHarness(cached: stations)
        let task = Task { await harness.viewModel.start() }
        harness.viewModel.text = "shell"
        await harness.waitUntil { $0.state.content != nil }
        harness.viewModel.text = "  "
        #expect(harness.viewModel.isIdle)
        #expect(harness.viewModel.state == .firstLoad)
        task.cancel()
    }

    @Test func offlinePostcodeElsewhereFails() async {
        let harness = SearchHarness(cached: stations, remoteError: .offline)
        let task = Task { await harness.viewModel.start() }
        harness.viewModel.text = "45600"
        await harness.waitUntil { $0.state == .failed(.offline) }
        #expect(harness.viewModel.state == .failed(.offline))
        task.cancel()
    }

    @Test func togglingAStarReRuns() async throws {
        let harness = SearchHarness(cached: stations)
        let task = Task { await harness.viewModel.start() }
        harness.viewModel.text = "shell"
        await harness.waitUntil { $0.state.content != nil }
        let summary = try #require(harness.viewModel.state.content?.rows.first?.summary)

        await harness.viewModel.toggleFavorite(summary)
        await harness.waitUntil { $0.state.content?.rows.first?.summary.isFavorite == true }
        #expect(harness.viewModel.state.content?.rows.first?.summary.isFavorite == true)
        task.cancel()
    }
}
