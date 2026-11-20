import DomainLayer
import Foundation
import Testing
import ViewModelLayer

@Suite("Tent board station choice")
struct TentBoardChoiceTests {
    func summary(_ id: String, _ price: String, distance: Double?, open: Bool) -> StationSummary {
        let station = Fixtures.station(id, diesel: price)
        return StationSummary(station: station, price: station.price(for: .diesel)!, level: .average, distance: distance,
                              openingStatus: open ? .alwaysOpen : .closed(opensAt: nil), isFavorite: false)
    }

    var nearby: [StationSummary] {
        [summary("closed-cheapest", "1.399", distance: 300, open: false),
         summary("open-cheap", "1.459", distance: 1200, open: true),
         summary("open-dear", "1.559", distance: 800, open: true)]
    }

    @Test func picksTheCheapestOpenStationNearby() {
        let choice = TentBoardChoice(selected: nil, nearby: nearby)
        #expect(choice.stationID == StationID("open-cheap"))
        #expect(choice.isPicked)
        #expect(choice.caption(isFavorite: true) == .cheapestNearby)
        #expect(choice.nearbyDistance == 1200)
        // The other open one, not the closed one that's nearer.
        #expect(choice.nearestOpen == 800)
    }

    @Test func atNightTheCheapestOverall() {
        let closed = [summary("a", "1.499", distance: 500, open: false), summary("b", "1.399", distance: 900, open: false)]
        let choice = TentBoardChoice(selected: nil, nearby: closed)
        #expect(choice.stationID == StationID("b"))
        #expect(choice.nearestOpen == nil)
    }

    @Test func theSelectionWins() {
        let choice = TentBoardChoice(selected: StationID("open-dear"), nearby: nearby)
        #expect(choice.stationID == StationID("open-dear"))
        #expect(!choice.isPicked)
        #expect(choice.caption(isFavorite: true) == .favorite)
        #expect(choice.caption(isFavorite: false) == nil)
        #expect(choice.nearestOpen == 1200)
    }

    @Test func nothingNearbyYet() {
        let choice = TentBoardChoice(selected: nil, nearby: [])
        #expect(choice.stationID == nil)
        #expect(choice.nearbyDistance == nil)
    }
}
