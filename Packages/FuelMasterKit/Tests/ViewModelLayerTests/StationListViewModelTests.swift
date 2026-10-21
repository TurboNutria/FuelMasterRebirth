import DomainLayer
import Foundation
import Testing
import ViewModelLayer

@Suite("Gasolineras view model")
@MainActor
struct StationListViewModelTests {
    let stations = [
        Fixtures.station("cheap", diesel: "1.800", metersNorth: 1200),
        Fixtures.station("mid", diesel: "1.900", metersNorth: 300),
        Fixtures.station("dear", diesel: "2.000", metersNorth: 800),
        Fixtures.station("far", diesel: "1.700", metersNorth: 9000),
    ]

    @Test func firstLoadThenContentFromTheMinistry() async {
        let harness = ListHarness(remote: stations)
        #expect(harness.viewModel.state == .firstLoad)
        let task = await harness.start { $0.state.content != nil }
        defer { task.cancel() }

        let ids = harness.viewModel.state.content?.rows.map(\.id.rawValue)
        // The far station is outside the 3 km radius.
        #expect(ids == ["cheap", "mid", "dear"])
        #expect(harness.viewModel.scope == .nearby(radius: 3000))
        #expect(harness.viewModel.state.content?.rows.first?.summary.distance != nil)
    }

    @Test func cachedPricesShowWithoutRefetching() async {
        let harness = ListHarness(cached: stations)
        let task = await harness.start { if case .content = $0.state { true } else { false } }
        defer { task.cancel() }
        #expect(harness.viewModel.state.content?.rows.count == 3)
        #expect(await harness.remote.calls == 0)
    }

    @Test func sortingAndLevelFilter() async {
        let harness = ListHarness(cached: stations)
        let task = await harness.start { $0.state.content != nil }
        defer { task.cancel() }

        harness.viewModel.sort = .nearest
        await harness.waitUntil { $0.state.content?.rows.first?.id.rawValue == "mid" }
        #expect(harness.viewModel.state.content?.rows.map(\.id.rawValue) == ["mid", "dear", "cheap"])

        // The area average includes the far station: (1.8 + 1.9 + 2.0 + 1.7) / 4 = 1.85.
        harness.viewModel.levelFilter = .expensive
        await harness.waitUntil { $0.state.content?.rows.count == 1 }
        #expect(harness.viewModel.state.content?.rows.map(\.id.rawValue) == ["dear"])

        harness.viewModel.levelFilter = .cheap
        await harness.waitUntil { $0.state.content == nil }
        #expect(harness.viewModel.state == .empty(.noStationsAtLevel(.cheap)))
    }

    @Test func noFuelNearbyReportsTheClosestStation() async {
        let harness = ListHarness(cached: [Fixtures.station("far", diesel: "1.700", metersNorth: 7400)])
        let task = await harness.start { if case .empty = $0.state { true } else { false } }
        defer { task.cancel() }
        await harness.waitUntil {
            if case .empty(.noStationsNearby(_, let nearest)) = $0.state { nearest != nil } else { false }
        }
        guard case .empty(.noStationsNearby(.diesel, let nearest?)) = harness.viewModel.state else {
            Issue.record("Expected an empty state with the nearest distance")
            return
        }
        #expect(abs(nearest - 7400) < 50)
    }

    @Test func offlineKeepsTheCacheAndThePillCanBeDismissed() async {
        let harness = ListHarness(cached: stations)
        let task = await harness.start { $0.state.content != nil }
        defer { task.cancel() }

        harness.connectivity.channel.send(.offline)
        await harness.waitUntil { $0.isOfflinePillVisible }
        guard case .offline(let content, let age?) = harness.viewModel.state else {
            Issue.record("Expected the offline state")
            return
        }
        #expect(content.rows.count == 3)
        #expect(age == 12 * 60)

        harness.viewModel.dismissOfflinePill()
        #expect(!harness.viewModel.isOfflinePillVisible)

        // Coming back online clears the dismissal for next time.
        harness.connectivity.channel.send(.online)
        await harness.waitUntil { if case .content = $0.state { true } else { false } }
        harness.connectivity.channel.send(.offline)
        await harness.waitUntil { $0.isOfflinePillVisible }
        #expect(harness.viewModel.isOfflinePillVisible)
    }

    @Test func noCacheAndNoNetworkFails() async {
        let harness = ListHarness(remoteError: .offline)
        let task = await harness.start { if case .failed = $0.state { true } else { false } }
        defer { task.cancel() }
        harness.connectivity.channel.send(.offline)
        await harness.waitUntil { $0.state == .failed(.offline) }
        #expect(harness.viewModel.state == .failed(.offline))
    }

    @Test func withoutLocationTheDefaultProvinceIsUsed() async {
        var settings = Settings.default
        settings.defaultProvinceID = ProvinceID("28")
        let harness = ListHarness(cached: stations, location: FakeLocation(authorization: .denied, fix: nil),
                                  settings: settings)
        let task = await harness.start { $0.state.content != nil }
        defer { task.cancel() }
        #expect(harness.viewModel.scope == .province(name: "Madrid"))
        // The whole province, so the far station is in, and there are no distances.
        #expect(harness.viewModel.state.content?.rows.count == 4)
        #expect(harness.viewModel.state.content?.rows.allSatisfy { $0.summary.distance == nil } == true)
    }

    @Test func aLateFirstFixReplacesTheDefaultProvince() async {
        let harness = ListHarness(cached: stations, location: FakeLocation(fix: Fixtures.sol, delay: .milliseconds(300)),
                                  firstFixTimeout: .milliseconds(50))
        let task = await harness.start { $0.scope == .province(name: "Madrid") }
        defer { task.cancel() }
        // The area switches first; the rows follow once the cache is read again.
        await harness.waitUntil { $0.scope == .nearby(radius: 3000) && $0.state.content?.rows.count == 3 }
        #expect(harness.viewModel.scope == .nearby(radius: 3000))
        #expect(harness.viewModel.state.content?.rows.count == 3)
    }

    @Test func choosingAFuelIsSaved() async {
        let harness = ListHarness(cached: stations)
        let task = await harness.start { $0.state.content != nil }
        defer { task.cancel() }

        await harness.viewModel.select(.petrol95E5)
        await harness.waitUntil { $0.state.content?.rows.first?.summary.price.product == .petrol95E5 }
        #expect(harness.viewModel.product == .petrol95E5)
        #expect(await harness.settings.settings.product == .petrol95E5)
    }
}
