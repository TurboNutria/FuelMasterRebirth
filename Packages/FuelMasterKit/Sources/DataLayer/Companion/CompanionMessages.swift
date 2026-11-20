import DomainLayer
import Foundation
import OSLog

// What the iPhone and the watch tell each other (Bear note 06, "iPhone ↔ watch sync").

/// The iPhone's state as the watch needs it. Sent as WatchConnectivity's application context,
/// so only the latest one is delivered.
public struct CompanionContext: Codable, Sendable, Equatable {
    public var product: Product
    /// When the fuel last changed on either device: the newer change wins.
    public var productChangedAt: Date
    public var accent: AccentChoice
    public var priceScale: PriceScale
    public var defaultProvinceID: ProvinceID?
    public var lastViewedProvinceID: ProvinceID?
    public var lastLocation: Coordinate?
    /// In the iPhone's order.
    public var favorites: [CompanionFavorite]

    public init(product: Product, productChangedAt: Date, accent: AccentChoice, priceScale: PriceScale,
                defaultProvinceID: ProvinceID?, lastViewedProvinceID: ProvinceID?, lastLocation: Coordinate?,
                favorites: [CompanionFavorite]) {
        self.product = product
        self.productChangedAt = productChangedAt
        self.accent = accent
        self.priceScale = priceScale
        self.defaultProvinceID = defaultProvinceID
        self.lastViewedProvinceID = lastViewedProvinceID
        self.lastLocation = lastLocation
        self.favorites = favorites
    }
}

public struct CompanionFavorite: Codable, Sendable, Hashable {
    public let stationID: StationID
    public let provinceID: ProvinceID

    public init(stationID: StationID, provinceID: ProvinceID) {
        self.stationID = stationID
        self.provinceID = provinceID
    }
}

/// What the watch asks the iPhone to do. Sent as queued user info, so it arrives even after
/// the phone was away or the apps were closed.
public enum CompanionRequest: Codable, Sendable, Equatable {
    case addFavorite(StationID, province: ProvinceID)
    case removeFavorite(StationID)
    case setProduct(Product, changedAt: Date)
}

extension Logger {
    /// iPhone ↔ watch sync. Read with `log show --predicate 'category == "companion"' --info`.
    static let companion = Logger(subsystem: "com.turbonutria.fuelmasterrebirth", category: "companion")
}

enum CompanionCoding {
    static func encode<Value: Encodable>(_ value: Value) -> Data? {
        try? JSONEncoder().encode(value)
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) -> Value? {
        try? JSONDecoder().decode(type, from: data)
    }
}
