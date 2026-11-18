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
        case .station(let summary): Self.stationPinID(summary.id)
        case .cluster(let cheapest, _, _): "c-\(cheapest.id.rawValue)"
        case .placeholder(let id, _): "p-\(id)"
        }
    }

    /// The `id` of a single station's pin.
    public static func stationPinID(_ station: StationID) -> String { "s-\(station.rawValue)" }

    public var coordinate: Coordinate {
        switch self {
        case .station(let summary): summary.station.coordinate
        case .cluster(let cheapest, _, _): cheapest.station.coordinate
        case .placeholder(_, let coordinate): coordinate
        }
    }
}

/// Groups only pins that would sit on top of each other, at any zoom. A price chip is about
/// 52 × 24 pt; pins group when their centres are closer than most of a chip, so neighbours may
/// touch or overlap a little. Grouping whenever the boxes touched hid most prices until street level.
/// Works in Web Mercator screen points, so it matches what the map draws.
public struct PinClusterer: Sendable {
    public static let pinSize = (width: 40.0, height: 18.0)

    public let width: Double
    public let height: Double

    public init(width: Double = PinClusterer.pinSize.width, height: Double = PinClusterer.pinSize.height) {
        self.width = width
        self.height = height
    }

    /// `width` is the map's width in points for the viewport's longitude span.
    public func pins(for stations: [StationSummary], in viewport: MapViewport, width mapWidth: Double) -> [StationPin] {
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
        // Groups by the pin-sized cell they sit in, so a station only looks at the groups around
        // it instead of at every group so far.
        struct Cell: Hashable {
            let column: Int
            let row: Int
        }
        var cells: [Cell: [Int]] = [:]
        for summary in ordered {
            let p = point(summary.station.coordinate)
            guard p.x.isFinite, p.y.isFinite else { continue }
            let cell = Cell(column: Int((p.x / width).rounded(.down)), row: Int((p.y / height).rounded(.down)))
            // The earliest group in reach, which is the cheapest one.
            var match: Int?
            for column in (cell.column - 1)...(cell.column + 1) {
                for row in (cell.row - 1)...(cell.row + 1) {
                    for index in cells[Cell(column: column, row: row)] ?? []
                    where abs(groups[index].x - p.x) < width && abs(groups[index].y - p.y) < height {
                        match = min(match ?? index, index)
                    }
                }
            }
            if let match {
                groups[match].members.append(summary)
            } else {
                cells[cell, default: []].append(groups.count)
                groups.append(Group(members: [summary], x: p.x, y: p.y))
            }
        }

        return groups.map { group in
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
