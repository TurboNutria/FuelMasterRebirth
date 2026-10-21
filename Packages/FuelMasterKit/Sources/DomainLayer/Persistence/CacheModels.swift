import Foundation
import SwiftData

// Local cache: lives in the App Group container, never synced.
// Unique constraints are fine here because CloudKit never sees this store.

@Model
public final class CachedStation {
    @Attribute(.unique) public var stationID: String
    public var name: String
    public var street: String
    public var postcode: String
    public var locality: String
    public var municipality: String
    public var municipalityID: String
    public var provinceName: String
    public var provinceID: String
    public var latitude: Double
    public var longitude: Double
    public var roadSide: String
    public var hoursText: String
    public var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \CachedPrice.station)
    public var prices: [CachedPrice] = []

    public init(stationID: String, name: String, street: String, postcode: String, locality: String,
                municipality: String, municipalityID: String, provinceName: String, provinceID: String,
                latitude: Double, longitude: Double, roadSide: String, hoursText: String, updatedAt: Date) {
        self.stationID = stationID
        self.name = name
        self.street = street
        self.postcode = postcode
        self.locality = locality
        self.municipality = municipality
        self.municipalityID = municipalityID
        self.provinceName = provinceName
        self.provinceID = provinceID
        self.latitude = latitude
        self.longitude = longitude
        self.roadSide = roadSide
        self.hoursText = hoursText
        self.updatedAt = updatedAt
    }
}

@Model
public final class CachedPrice {
    public var productID: Int
    public var amount: Decimal
    public var snapshotDate: Date
    public var station: CachedStation?

    public init(productID: Int, amount: Decimal, snapshotDate: Date) {
        self.productID = productID
        self.amount = amount
        self.snapshotDate = snapshotDate
    }
}

@Model
public final class CachedHistoryPoint {
    #Index<CachedHistoryPoint>([\.stationID, \.productID, \.day])
    public var stationID: String
    public var provinceID: String
    public var productID: Int
    public var day: Date
    public var amount: Decimal

    public init(stationID: String, provinceID: String, productID: Int, day: Date, amount: Decimal) {
        self.stationID = stationID
        self.provinceID = provinceID
        self.productID = productID
        self.day = day
        self.amount = amount
    }
}

@Model
public final class CachedAreaHistory {
    public var provinceID: String
    public var productID: Int
    public var day: Date
    public var average: Decimal

    public init(provinceID: String, productID: Int, day: Date, average: Decimal) {
        self.provinceID = provinceID
        self.productID = productID
        self.day = day
        self.average = average
    }
}

/// Freshness bookkeeping per province.
@Model
public final class CachedProvinceSnapshot {
    @Attribute(.unique) public var provinceID: String
    public var snapshotDate: Date
    public var fetchedAt: Date
    public var stationCount: Int

    public init(provinceID: String, snapshotDate: Date, fetchedAt: Date, stationCount: Int) {
        self.provinceID = provinceID
        self.snapshotDate = snapshotDate
        self.fetchedAt = fetchedAt
        self.stationCount = stationCount
    }
}

public enum CacheSchema {
    public static let models: [any PersistentModel.Type] = [
        CachedStation.self, CachedPrice.self, CachedHistoryPoint.self,
        CachedAreaHistory.self, CachedProvinceSnapshot.self,
    ]
}
