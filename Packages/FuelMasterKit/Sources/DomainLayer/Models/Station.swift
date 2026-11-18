import Foundation

public struct Coordinate: Hashable, Sendable, Codable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance in metres.
    public func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180, lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(a)))
    }
}

public struct Address: Hashable, Sendable, Codable {
    public let street: String
    public let postcode: String
    public let locality: String
    public let municipality: String
    public let province: String

    public init(street: String, postcode: String, locality: String, municipality: String, province: String) {
        self.street = street
        self.postcode = postcode
        self.locality = locality
        self.municipality = municipality
        self.province = province
    }
}

/// Side of the road, from the ministry's `Margen`.
public enum RoadSide: String, Sendable, Codable {
    case right
    case left
    case notApplicable
}

public struct Station: Hashable, Sendable, Identifiable {
    public let id: StationID
    /// Cleaned-up brand or sign, e.g. "Repsol".
    public let name: String
    public let address: Address
    public let coordinate: Coordinate
    public let roadSide: RoadSide
    public let hours: OpeningHours
    public let provinceID: ProvinceID
    public let municipalityID: MunicipalityID
    public let prices: [Product: Price]

    public init(id: StationID, name: String, address: Address, coordinate: Coordinate, roadSide: RoadSide,
                hours: OpeningHours, provinceID: ProvinceID, municipalityID: MunicipalityID, prices: [Product: Price]) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.roadSide = roadSide
        self.hours = hours
        self.provinceID = provinceID
        self.municipalityID = municipalityID
        self.prices = prices
    }

    public func price(for product: Product) -> Price? { prices[product] }
}

/// One row, pin or widget line.
public struct StationSummary: Hashable, Sendable, Identifiable {
    public let station: Station
    public let price: Price
    public let level: PriceLevel
    /// Metres from the user, when the location is known.
    public let distance: Double?
    public let openingStatus: OpeningStatus
    public let isFavorite: Bool

    public init(station: Station, price: Price, level: PriceLevel, distance: Double?,
                openingStatus: OpeningStatus, isFavorite: Bool) {
        self.station = station
        self.price = price
        self.level = level
        self.distance = distance
        self.openingStatus = openingStatus
        self.isFavorite = isFavorite
    }

    public var id: StationID { station.id }
}
