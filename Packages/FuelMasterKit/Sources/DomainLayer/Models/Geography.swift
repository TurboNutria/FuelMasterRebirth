import Foundation

public struct BoundingBox: Hashable, Sendable, Codable {
    public let minLatitude: Double
    public let minLongitude: Double
    public let maxLatitude: Double
    public let maxLongitude: Double

    public init(minLatitude: Double, minLongitude: Double, maxLatitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.minLongitude = minLongitude
        self.maxLatitude = maxLatitude
        self.maxLongitude = maxLongitude
    }

    public func intersects(_ other: BoundingBox) -> Bool {
        minLatitude <= other.maxLatitude && maxLatitude >= other.minLatitude
            && minLongitude <= other.maxLongitude && maxLongitude >= other.minLongitude
    }

    public func contains(_ point: Coordinate) -> Bool {
        (minLatitude...maxLatitude).contains(point.latitude) && (minLongitude...maxLongitude).contains(point.longitude)
    }

    public var center: Coordinate {
        Coordinate(latitude: (minLatitude + maxLatitude) / 2, longitude: (minLongitude + maxLongitude) / 2)
    }

    /// Grows the box by `degrees` on every side.
    public func expanded(by degrees: Double) -> BoundingBox {
        BoundingBox(minLatitude: minLatitude - degrees, minLongitude: minLongitude - degrees,
                    maxLatitude: maxLatitude + degrees, maxLongitude: maxLongitude + degrees)
    }
}

public struct Province: Hashable, Sendable, Identifiable {
    public let id: ProvinceID
    public let name: String
    public let regionID: String
    public let bounds: BoundingBox
    /// Approximate outline: the convex hull of the province's stations.
    public let outline: [Coordinate]
    /// Station points used to break ties where outlines overlap.
    public let samples: [Coordinate]

    public init(id: ProvinceID, name: String, regionID: String, bounds: BoundingBox,
                outline: [Coordinate], samples: [Coordinate]) {
        self.id = id
        self.name = name
        self.regionID = regionID
        self.bounds = bounds
        self.outline = outline
        self.samples = samples
    }
}

public struct Municipality: Hashable, Sendable, Identifiable {
    public let id: MunicipalityID
    public let name: String
    public let provinceID: ProvinceID

    public init(id: MunicipalityID, name: String, provinceID: ProvinceID) {
        self.id = id
        self.name = name
        self.provinceID = provinceID
    }
}

public struct MapViewport: Hashable, Sendable {
    public let center: Coordinate
    public let latitudeDelta: Double
    public let longitudeDelta: Double

    public init(center: Coordinate, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    public var bounds: BoundingBox {
        BoundingBox(minLatitude: center.latitude - latitudeDelta / 2,
                    minLongitude: center.longitude - longitudeDelta / 2,
                    maxLatitude: center.latitude + latitudeDelta / 2,
                    maxLongitude: center.longitude + longitudeDelta / 2)
    }
}
