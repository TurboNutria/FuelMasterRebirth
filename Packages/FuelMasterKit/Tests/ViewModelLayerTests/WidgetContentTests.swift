import DomainLayer
import Foundation
import Testing
import ViewModelLayer

@Suite("Widget content")
struct WidgetContentTests {
    let now = Fixtures.date(2026, 11, 18, 10, 0)
    let format = DisplayFormat(locale: Locale(identifier: "es_ES"))

    private func summary(_ id: String, _ price: String, level: PriceLevel = .cheap, distance: Double? = 1400) -> StationSummary {
        let station = Fixtures.station(id, diesel: price)
        return StationSummary(station: station, price: station.price(for: .diesel)!, level: level, distance: distance,
                              openingStatus: .alwaysOpen, isFavorite: false)
    }

    private func snapshot(fetchedMinutesAgo minutes: Double, favorites: [FavoriteSummary] = []) -> WidgetSnapshot {
        let freshness = Freshness(snapshotDate: now.addingTimeInterval(-minutes * 60 - 300),
                                  fetchedAt: now.addingTimeInterval(-minutes * 60))
        return WidgetSnapshot(
            product: .diesel, priceScale: .trafficLight, cheapest: summary("1", "1.859"),
            summary: AreaPriceSummary(product: .diesel, average: Decimal(string: "1.924")!, minimum: Decimal(string: "1.739")!,
                                      maximum: Decimal(string: "2.049")!, stationCount: 40, provinces: [ProvinceID("28")],
                                      snapshotDate: nil),
            favorites: favorites, freshness: freshness, favoritesFreshness: favorites.isEmpty ? nil : freshness
        )
    }

    @Test("Fresh prices: distance, gap to the average and link, no age")
    func freshContent() {
        let content = WidgetContent(snapshot(fetchedMinutesAgo: 12), at: now, format: format)
        #expect(content.cheapest?.distance == "1,4 km")
        #expect(content.cheapest?.belowAverage == Decimal(string: "0.065"))
        #expect(content.cheapest?.link == URL(string: "fuelmaster://station/1"))
        #expect(content.staleAge == nil)
    }

    @Test("Over an hour old: the age shows")
    func staleContent() {
        let content = WidgetContent(snapshot(fetchedMinutesAgo: 180), at: now, format: format)
        #expect(content.staleAge != nil)
        #expect(content.staleAge?.contains("3") == true)
    }

    @Test("The timeline redraws when the prices turn an hour old")
    func staleDate() {
        let snapshot = snapshot(fetchedMinutesAgo: 12)
        let date = WidgetContent.staleDate(of: snapshot)
        #expect(date == now.addingTimeInterval(-12 * 60 + 3601))
        #expect(WidgetContent(snapshot, at: date!, format: format).staleAge != nil)
    }

    @Test("Gauge: where the price falls between the area's cheapest and dearest")
    func gauge() {
        let content = WidgetContent(snapshot(fetchedMinutesAgo: 5), at: now, format: format)
        // (1.859 - 1.739) / (2.049 - 1.739) ≈ 0.387
        #expect(abs((content.gaugeFraction ?? 0) - 0.387) < 0.01)
    }

    @Test("Favourites keep their change since yesterday")
    func favorites() {
        let change = PriceChange(difference: Decimal(string: "-0.005")!, comparedDay: now)
        let entry = FavoriteEntry(stationID: StationID("2"), provinceID: ProvinceID("28"), order: 0)
        let item = FavoriteSummary(entry: entry, station: nil, summary: summary("2", "1.934", level: .average), change: change)
        let content = WidgetContent(snapshot(fetchedMinutesAgo: 5, favorites: [item]), at: now, format: format)
        #expect(content.favorites.map(\.id) == [StationID("2")])
        #expect(content.favorites.first?.change == change)
        #expect(content.favoritesStaleAge == nil)
    }

    @Test("Station links round-trip, and other URLs are ignored")
    func links() {
        #expect(StationLink.station(from: StationLink.url(for: StationID("3213"))) == StationID("3213"))
        #expect(StationLink.station(from: URL(string: "fuelmaster://station/")!) == nil)
        #expect(StationLink.station(from: URL(string: "https://example.com/station/1")!) == nil)
    }
}

@Suite("Widget links")
@MainActor
struct WidgetLinkRouterTests {
    @Test("A widget tap from Ajustes opens the detail on Gasolineras")
    func fromSettings() {
        let router = AppRouter(selectedTab: .settings)
        #expect(router.open(StationLink.url(for: StationID("3213"))))
        #expect(router.selectedTab == .list)
        #expect(router.selectedStationID == StationID("3213"))
        #expect(router.isDetailPresented)
    }

    @Test("Favoritos stays the tab, and the panel layouts keep theirs")
    func keepsStationTabs() {
        let router = AppRouter(selectedTab: .favorites)
        router.open(StationLink.url(for: StationID("1")))
        #expect(router.selectedTab == .favorites)

        let split = AppRouter(selectedTab: .settings, layoutMode: .split)
        split.open(StationLink.url(for: StationID("1")))
        #expect(split.selectedTab == .settings)
        #expect(split.presentsDetailBesideMap)
    }

    @Test("Unknown URLs do nothing")
    func ignoresOthers() {
        let router = AppRouter(selectedTab: .map)
        #expect(!router.open(URL(string: "fuelmaster://settings")!))
        #expect(router.selectedStationID == nil)
    }
}
