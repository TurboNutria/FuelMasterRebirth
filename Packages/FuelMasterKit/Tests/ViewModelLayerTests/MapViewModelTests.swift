import DomainLayer
import Foundation
import Testing
import ViewModelLayer

@Suite("Pin clustering")
struct PinClustererTests {
    func summary(_ id: String, _ price: String, latitude: Double, longitude: Double = -3.7035) -> StationSummary {
        let station = Fixtures.station(id, diesel: price, metersNorth: (latitude - Fixtures.sol.latitude) * 111_000)
        let moved = Station(id: station.id, name: station.name, address: station.address,
                            coordinate: Coordinate(latitude: latitude, longitude: longitude), roadSide: .notApplicable,
                            hours: station.hours, provinceID: station.provinceID, municipalityID: station.municipalityID,
                            prices: station.prices)
        return StationSummary(station: moved, price: Price(amount: Decimal(string: price)!, product: .diesel),
                              level: .average, distance: nil, openingStatus: .alwaysOpen, isFavorite: false)
    }

    // 0.06° of longitude across 390 pt: about 5 m per point near Madrid.
    let viewport = MapViewport(center: Fixtures.sol, latitudeDelta: 0.06, longitudeDelta: 0.06)

    @Test func pinsFarApartStaySeparate() {
        let pins = PinClusterer().pins(for: [summary("a", "1.900", latitude: 40.41), summary("b", "1.800", latitude: 40.43)],
                                       in: viewport, width: 390)
        #expect(pins.count == 2)
        #expect(pins.allSatisfy { if case .station = $0 { true } else { false } })
    }

    @Test func overlappingPinsGroupUnderTheCheapest() {
        // About 20 m apart: a few points on screen, so the chips would overlap.
        let pins = PinClusterer().pins(for: [summary("a", "1.900", latitude: 40.4169), summary("b", "1.850", latitude: 40.4171),
                                             summary("c", "1.990", latitude: 40.4300)],
                                       in: viewport, width: 390)
        #expect(pins.count == 2)
        guard case .cluster(let cheapest, let count, let bounds) = pins.first(where: { $0.id.hasPrefix("c-") }) else {
            Issue.record("Expected a cluster")
            return
        }
        #expect(cheapest.id.rawValue == "b")
        #expect(count == 2)
        #expect(bounds.contains(Coordinate(latitude: 40.417, longitude: -3.7035)))
    }

    @Test func neighbouringChipsStaySeparate() {
        // 0.0075° of longitude is about 49 pt here: the chips touch at most, so both prices show.
        let pins = PinClusterer().pins(for: [summary("a", "1.900", latitude: 40.4169, longitude: -3.7035),
                                             summary("b", "1.850", latitude: 40.4169, longitude: -3.6960)],
                                       in: viewport, width: 390)
        #expect(pins.count == 2)
    }

    @Test func aDenseAreaGroupsEveryStationOnce() {
        // 3,000 stations on a 60 × 50 grid about 5 pt apart: every chip overlaps its neighbours.
        let stations = (0..<3000).map { index in
            summary("s\(index)", "1.\(500 + index % 400)", latitude: 40.40 + Double(index / 60) * 0.0006,
                    longitude: -3.72 + Double(index % 60) * 0.0008)
        }
        let pins = PinClusterer().pins(for: stations, in: viewport, width: 390)
        let counted = pins.reduce(0) { total, pin in
            if case .cluster(_, let count, _) = pin { total + count } else { total + 1 }
        }
        #expect(counted == 3000)
        #expect(pins.count < 400)
        #expect(Set(pins.map(\.id)).count == pins.count)
    }

    @Test func zoomingInSeparatesThem() {
        let close = [summary("a", "1.900", latitude: 40.4169), summary("b", "1.850", latitude: 40.4171)]
        let streetLevel = MapViewport(center: Fixtures.sol, latitudeDelta: 0.001, longitudeDelta: 0.001)
        #expect(PinClusterer().pins(for: close, in: streetLevel, width: 390).count == 2)
    }
}

@Suite("Map view model")
@MainActor
struct MapViewModelTests {
    let stations = [
        Fixtures.station("cheap", diesel: "1.800", metersNorth: 1200),
        Fixtures.station("mid", diesel: "1.900", metersNorth: 300),
        Fixtures.station("dear", diesel: "2.000", metersNorth: 2500),
        Fixtures.station("far", diesel: "1.700", metersNorth: 9000),
    ]
    let aroundSol = MapViewport(center: Fixtures.sol, latitudeDelta: 0.06, longitudeDelta: 0.06)

    @Test func opensOnTheUserAndLoadsTheViewport() async {
        let harness = MapHarness(remote: stations)
        let task = Task { await harness.viewModel.start() }
        defer { task.cancel() }
        await harness.waitUntil { $0.cameraMove != nil }
        #expect(harness.viewModel.cameraMove?.viewport.center == Fixtures.sol)

        harness.viewModel.viewportChanged(aroundSol, width: 390)
        await harness.waitUntil { $0.state.content != nil }
        // The far station (9 km north) is outside a 0.06° viewport.
        #expect(harness.viewModel.state.content?.pins.count == 3)
        #expect(await harness.remote.calls == 1)
    }

    @Test func theMapsOwnFirstCameraDoesNotWinOverTheUser() async {
        let harness = MapHarness(cached: stations)
        // MapKit reports its default region before the screen's task starts.
        harness.viewModel.viewportChanged(MapViewport(center: Coordinate(latitude: 40, longitude: -4),
                                                      latitudeDelta: 8, longitudeDelta: 8), width: 390)
        let task = Task { await harness.viewModel.start() }
        defer { task.cancel() }
        await harness.waitUntil { $0.cameraMove != nil }
        #expect(harness.viewModel.cameraMove?.viewport.center == Fixtures.sol)
        #expect(harness.viewModel.cameraMove?.viewport.latitudeDelta == MapViewModel.initialSpan)
    }

    @Test func aLateFirstFixMovesTheMapFromTheDefaultProvince() async {
        // The fix takes longer than the first-fix wait, so the map opens on the default province first.
        let harness = MapHarness(cached: stations, location: FakeLocation(fix: Fixtures.sol, delay: .milliseconds(300)),
                                 firstFixTimeout: .milliseconds(50))
        let task = Task { await harness.viewModel.start() }
        defer { task.cancel() }
        await harness.waitUntil { $0.cameraMove?.viewport.center == Fixtures.madrid.bounds.center }
        #expect(harness.viewModel.userLocation == nil)
        await harness.waitUntil { $0.userLocation != nil }
        #expect(harness.viewModel.cameraMove?.viewport.center == Fixtures.sol)
    }

    @Test func anOverlappingOldScreenDoesNotStopTheNewOne() async {
        // Tabs → split on launch: the tab layout's map starts, the split's map starts, and only then
        // is the first one's task cancelled. The map must keep following the cache.
        let harness = MapHarness(cached: stations)
        let first = Task { await harness.viewModel.start() }
        let second = Task { await harness.viewModel.start() }
        defer { second.cancel() }
        harness.viewModel.viewportChanged(aroundSol, width: 390)
        await harness.waitUntil { $0.state.content != nil }
        first.cancel()
        try? await Task.sleep(for: .milliseconds(50))

        let cheaper = Fixtures.station("new", diesel: "1.500", metersNorth: 100)
        try? await harness.cache.save(ProvinceSnapshot(provinceID: ProvinceID("28"), stations: stations + [cheaper],
                                                       snapshotDate: ListHarness.now), fetchedAt: ListHarness.now)
        // Alone or leading a group, the new cheapest station reaches the map.
        await harness.waitUntil { $0.state.content?.pins.contains { $0.id.hasSuffix("-new") } == true }
        #expect(harness.viewModel.state.content?.pins.contains { $0.id.hasSuffix("-new") } == true)
    }

    @Test func firstLoadShowsGreyPinsInView() async {
        let harness = MapHarness(remote: stations, remoteDelay: .seconds(5))
        let task = Task { await harness.viewModel.start() }
        defer { task.cancel() }
        harness.viewModel.viewportChanged(aroundSol, width: 390)
        await harness.waitUntil { !$0.placeholderPins.isEmpty }
        #expect(harness.viewModel.state == .firstLoad)
        // Two of the three bundled samples are in view.
        #expect(harness.viewModel.placeholderPins.count == 2)
    }

    @Test func panningInsideTheLoadedAreaShowsPinsWithoutLoadingAgain() async {
        let harness = MapHarness(remote: stations)
        let task = Task { await harness.viewModel.start() }
        defer { task.cancel() }
        harness.viewModel.viewportChanged(aroundSol, width: 390)
        await harness.waitUntil { $0.state.content != nil }

        // Zoomed in on the station 1.2 km north: it's there at once, and nothing is fetched.
        let street = MapViewport(center: Coordinate(latitude: Fixtures.sol.latitude + 1200.0 / 111_000,
                                                    longitude: Fixtures.sol.longitude),
                                 latitudeDelta: 0.004, longitudeDelta: 0.004)
        harness.viewModel.viewportChanged(street, width: 390)
        #expect(harness.viewModel.state.content?.pins.map(\.id) == ["s-cheap"])
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await harness.remote.calls == 1)
    }

    @Test func leavingTheLoadedAreaLoadsTheNewOne() async {
        let harness = MapHarness(cached: stations)
        let task = Task { await harness.viewModel.start() }
        defer { task.cancel() }
        harness.viewModel.viewportChanged(aroundSol, width: 390)
        await harness.waitUntil { $0.state.content != nil }

        let north = MapViewport(center: Coordinate(latitude: Fixtures.sol.latitude + 9000.0 / 111_000,
                                                   longitude: Fixtures.sol.longitude),
                                latitudeDelta: 0.06, longitudeDelta: 0.06)
        harness.viewModel.viewportChanged(north, width: 390)
        await harness.waitUntil { $0.state.content?.pins.contains { $0.id == "s-far" } == true }
        #expect(harness.viewModel.state.content?.pins.contains { $0.id == "s-far" } == true)
    }

    @Test func theFuelMenuOffersOnlyWhatIsInView() async {
        let harness = MapHarness(cached: stations)
        let task = Task { await harness.viewModel.start() }
        defer { task.cancel() }
        #expect(harness.viewModel.offeredProducts == Product.allCases)
        harness.viewModel.viewportChanged(aroundSol, width: 390)
        await harness.waitUntil { $0.state.content != nil }
        // The fixtures sell diesel and Gasolina 95; nothing in view sells gas.
        #expect(harness.viewModel.offeredProducts == [.diesel, .petrol95E5])
    }

    @Test func zoomedOutLoadsNothing() async {
        let harness = MapHarness(remote: stations)
        let task = Task { await harness.viewModel.start() }
        defer { task.cancel() }
        harness.viewModel.viewportChanged(MapViewport(center: Fixtures.sol, latitudeDelta: 6, longitudeDelta: 6), width: 390)
        await harness.waitUntil { $0.isZoomedOut }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(harness.viewModel.isZoomedOut)
        #expect(await harness.remote.calls == 0)
    }

    @Test func clusterTapZoomsIn() async {
        let harness = MapHarness(cached: stations)
        let bounds = BoundingBox(minLatitude: 40.41, minLongitude: -3.71, maxLatitude: 40.42, maxLongitude: -3.70)
        harness.viewModel.zoom(into: bounds)
        let move = harness.viewModel.cameraMove
        #expect(move?.viewport.center == bounds.center)
        #expect((move?.viewport.latitudeDelta ?? 0) < 0.06)
    }

    @Test func focusMovesCloseToTheStation() {
        let harness = MapHarness(cached: stations)
        harness.viewModel.focus(on: Fixtures.sol)
        let move = harness.viewModel.cameraMove
        #expect(move?.viewport.center == Fixtures.sol)
        #expect(move?.viewport.latitudeDelta == MapViewModel.focusSpan)
    }

    @Test func levelFilterHidesOtherPins() async {
        let harness = MapHarness(cached: stations)
        let task = Task { await harness.viewModel.start() }
        defer { task.cancel() }
        harness.viewModel.viewportChanged(aroundSol, width: 390)
        await harness.waitUntil { $0.state.content != nil }
        harness.viewModel.levelFilter = .expensive
        await harness.waitUntil { $0.state.content?.pins.count == 1 }
        #expect(harness.viewModel.state.content?.pins.first?.id == "s-dear")
    }
}
