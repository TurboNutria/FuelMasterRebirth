import DomainLayer
import Foundation

/// Which station the Tent board shows, from the selection and Gasolineras' nearby stations: the
/// selected one, else the cheapest one that's open (the cheapest overall when none is, at night).
public struct TentBoardChoice: Sendable, Equatable {
    /// The line above the station's name.
    public enum Caption: Sendable, Equatable {
        /// Picked for the user: "Más barata cerca".
        case cheapestNearby
        /// The selected station is a favourite: "Favorita".
        case favorite
    }

    /// Nil while there's no selection and nothing nearby yet.
    public let stationID: StationID?
    /// True when the board picked the station rather than the user.
    public let isPicked: Bool
    /// How far the chosen station is, when it's among the nearby ones.
    public let nearbyDistance: Double?
    /// The closest other station that's open, for "Más cercana abierta" on a closed one.
    public let nearestOpen: Double?

    public init(selected: StationID?, nearby: [StationSummary]) {
        let open = nearby.filter { $0.openingStatus.isOpen }
        let id = selected ?? (open.isEmpty ? nearby : open).min { $0.price.amount < $1.price.amount }?.id
        stationID = id
        isPicked = selected == nil
        nearbyDistance = nearby.first { $0.id == id }?.distance
        nearestOpen = open.filter { $0.id != id }.compactMap(\.distance).min()
    }

    public func caption(isFavorite: Bool) -> Caption? {
        if isPicked { return .cheapestNearby }
        return isFavorite ? .favorite : nil
    }

    /// From the nearby list, else from the station's own detail (a selection outside the list).
    public func distance(for content: TentBoardContent) -> Double? {
        nearbyDistance ?? content.detail.distance
    }
}
