import Foundation

public struct HistoryPoint: Hashable, Sendable {
    /// Start of the day the snapshot belongs to.
    public let day: Date
    /// Missing when the station didn't report that day.
    public let amount: Decimal?

    public init(day: Date, amount: Decimal?) {
        self.day = day
        self.amount = amount
    }
}

public struct PriceHistory: Hashable, Sendable {
    public let stationID: StationID
    public let product: Product
    public let points: [HistoryPoint]
    public let areaAverage: [HistoryPoint]

    public init(stationID: StationID, product: Product, points: [HistoryPoint], areaAverage: [HistoryPoint]) {
        self.stationID = stationID
        self.product = product
        self.points = points
        self.areaAverage = areaAverage
    }

    public var minimum: Decimal? { points.compactMap(\.amount).min() }
    public var maximum: Decimal? { points.compactMap(\.amount).max() }

    /// Change from the first to the last day with a price.
    public var change: PriceChange? {
        let known = points.filter { $0.amount != nil }
        guard let first = known.first, let last = known.last, let a = first.amount, let b = last.amount,
              first.day != last.day else { return nil }
        return PriceChange(difference: b - a, comparedDay: first.day)
    }
}

/// One day's prices for a province and product, as returned by the history endpoint.
public struct HistorySnapshot: Sendable {
    public let provinceID: ProvinceID
    public let product: Product
    public let day: Date
    public let prices: [StationID: Decimal]

    public init(provinceID: ProvinceID, product: Product, day: Date, prices: [StationID: Decimal]) {
        self.provinceID = provinceID
        self.product = product
        self.day = day
        self.prices = prices
    }

    public var average: Decimal? {
        guard !prices.isEmpty else { return nil }
        return prices.values.reduce(0, +) / Decimal(prices.count)
    }
}

/// Current prices for every station of a province, as returned by the ministry.
public struct ProvinceSnapshot: Sendable {
    public let provinceID: ProvinceID
    public let stations: [Station]
    /// The ministry's `Fecha`.
    public let snapshotDate: Date

    public init(provinceID: ProvinceID, stations: [Station], snapshotDate: Date) {
        self.provinceID = provinceID
        self.stations = stations
        self.snapshotDate = snapshotDate
    }
}

public struct Freshness: Hashable, Sendable {
    public static let staleAfter: TimeInterval = 30 * 60

    public let snapshotDate: Date
    public let fetchedAt: Date

    public init(snapshotDate: Date, fetchedAt: Date) {
        self.snapshotDate = snapshotDate
        self.fetchedAt = fetchedAt
    }

    /// Stale when we last fetched more than 30 minutes ago.
    public func isStale(at now: Date) -> Bool { now.timeIntervalSince(fetchedAt) > Self.staleAfter }

    /// Age of the prices themselves, from the ministry's timestamp.
    public func age(at now: Date) -> TimeInterval { max(0, now.timeIntervalSince(snapshotDate)) }
}
