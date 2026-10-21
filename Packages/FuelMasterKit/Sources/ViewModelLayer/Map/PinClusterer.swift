import DomainLayer
import Foundation

/// One thing drawn on the map: a single station's price, or a group of stations whose pins
/// would overlap on screen.
public enum StationPin: Sendable, Equatable, Identifiable {
    case station(StationSummary)
    /// Drawn as a circle with `count`; `cheapest` is kept for VoiceOver ("6 gasolineras, desde 1,879 €")
    /// and tapping it zooms to `bounds`.
    case cluster(cheapest: StationSummary, count: Int, bounds: BoundingBox)
    /// First load: where stations are, before their prices arrive (grey "---").
    case placeholder(id: Int, Coordinate)

    public var id: String {
        switch self {
        case .station(let summary): "s-\(summary.id.rawValue)"
        case .cluster(let cheapest, _, _): "c-\(cheapest.id.rawValue)"
        case .placeholder(let id, _): "p-\(id)"
        }
    }

    public var coordinate: Coordinate {
        switch self {
        case .station(let summary): summary.station.coordinate
        case .cluster(let cheapest, _, _): cheapest.station.coordinate
        case .placeholder(_, let coordinate): coordinate
        }
    }
}

/// Groups only pins that would overlap, at any zoom. Note 06 says "about 44 pt apart"; in practice
/// a price chip is about 64 × 28 pt, so two pins group when those boxes would overlap.
/// Works in Web Mercator screen points, so it matches what the map draws.
public struct PinClusterer: Sendable {
    public static let pinSize = (width: 64.0, height: 28.0)

    public let width: Double
    public let height: Double

    public init(width: Double = PinClusterer.pinSize.width, height: Double = PinClusterer.pinSize.height) {
        self.width = width
        self.height = height
    }

    /// `width` is the map's width in points for the viewport's longitude span. `standalone` is never
    /// grouped (the highlighted cheapest station), so it always shows its own price.
    public func pins(for stations: [StationSummary], in viewport: MapViewport, width mapWidth: Double,
                     standalone: StationID? = nil) -> [StationPin] {
        guard mapWidth > 0, viewport.longitudeDelta > 0 else { return stations.map(StationPin.station) }
        let pointsPerRadian = mapWidth / (viewport.longitudeDelta * .pi / 180)

        func point(_ coordinate: Coordinate) -> (x: Double, y: Double) {
            let x = coordinate.longitude * .pi / 180 * pointsPerRadian
            let latitude = coordinate.latitude * .pi / 180
            let y = log(tan(.pi / 4 + latitude / 2)) * pointsPerRadian
            return (x, y)
        }

        struct Group {
            var members: [StationSummary]
            let x: Double
            let y: Double
        }

        // Cheapest first, so every group is led by its lowest price and that price stays visible.
        let ordered = stations.sorted { $0.price.amount < $1.price.amount }
        var groups: [Group] = []
        var separate: [StationPin] = []
        for summary in ordered {
            if summary.id == standalone {
                separate.append(.station(summary))
                continue
            }
            let p = point(summary.station.coordinate)
            if let index = groups.firstIndex(where: { abs($0.x - p.x) < width && abs($0.y - p.y) < height }) {
                groups[index].members.append(summary)
            } else {
                groups.append(Group(members: [summary], x: p.x, y: p.y))
            }
        }

        return separate + groups.map { group in
            guard group.members.count > 1 else { return .station(group.members[0]) }
            let coordinates = group.members.map(\.station.coordinate)
            let bounds = BoundingBox(
                minLatitude: coordinates.map(\.latitude).min()!, minLongitude: coordinates.map(\.longitude).min()!,
                maxLatitude: coordinates.map(\.latitude).max()!, maxLongitude: coordinates.map(\.longitude).max()!
            )
            return .cluster(cheapest: group.members[0], count: group.members.count, bounds: bounds)
        }
    }
}
