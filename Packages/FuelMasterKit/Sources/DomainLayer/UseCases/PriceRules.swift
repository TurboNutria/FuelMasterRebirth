import Foundation

/// Cheap / average / expensive against the area average, with a fixed ±0.06 € band in every province.
public struct ClassifyPrice: Sendable {
    public static let band: Decimal = Decimal(string: "0.06")!

    public init() {}

    public func callAsFunction(_ amount: Decimal, areaAverage: Decimal) -> PriceLevel {
        if amount <= areaAverage - Self.band { return .cheap }
        if amount >= areaAverage + Self.band { return .expensive }
        return .average
    }
}

/// Cost of filling the tank. None for AdBlue, which isn't a fuel.
public struct CalculateFuelCost: Sendable {
    public init() {}

    public func callAsFunction(price: Price, tankSize: Decimal) -> FuelCost? {
        guard price.product.isFuel, tankSize > 0 else { return nil }
        var amount = price.amount * tankSize
        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 2, .plain)
        return FuelCost(amount: rounded, quantity: tankSize, unit: price.unit)
    }
}

/// Builds the area summary used for the "media" label and the Lock Screen gauge.
public struct SummarizeArea: Sendable {
    public init() {}

    public func callAsFunction(_ stations: [Station], product: Product, provinces: [ProvinceID],
                               snapshotDate: Date?) -> AreaPriceSummary? {
        let amounts = stations.compactMap { $0.price(for: product)?.amount }
        guard let minimum = amounts.min(), let maximum = amounts.max() else { return nil }
        let average = amounts.reduce(0, +) / Decimal(amounts.count)
        return AreaPriceSummary(product: product, average: average, minimum: minimum, maximum: maximum,
                                stationCount: amounts.count, provinces: provinces, snapshotDate: snapshotDate)
    }
}
