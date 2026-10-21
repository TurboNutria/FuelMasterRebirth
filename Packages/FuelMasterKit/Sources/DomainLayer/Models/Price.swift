import Foundation

/// A price in euros per unit of the product, always kept to three decimals.
public struct Price: Hashable, Sendable, Codable {
    public let amount: Decimal
    public let product: Product

    public init(amount: Decimal, product: Product) {
        self.amount = amount
        self.product = product
    }

    public var unit: QuantityUnit { product.unit }
}

public enum PriceLevel: String, Sendable, Codable {
    case cheap
    case average
    case expensive
}

/// Average, cheapest and dearest price for one product across the loaded area.
public struct AreaPriceSummary: Hashable, Sendable {
    public let product: Product
    public let average: Decimal
    public let minimum: Decimal
    public let maximum: Decimal
    public let stationCount: Int
    public let provinces: [ProvinceID]
    public let snapshotDate: Date?

    public init(product: Product, average: Decimal, minimum: Decimal, maximum: Decimal,
                stationCount: Int, provinces: [ProvinceID], snapshotDate: Date?) {
        self.product = product
        self.average = average
        self.minimum = minimum
        self.maximum = maximum
        self.stationCount = stationCount
        self.provinces = provinces
        self.snapshotDate = snapshotDate
    }
}

public enum ChangeDirection: String, Sendable {
    case up
    case down
    case same
}

/// Difference against an earlier price, in euros ("↓ 0,020 €").
public struct PriceChange: Hashable, Sendable {
    public let difference: Decimal
    public let comparedDay: Date

    public init(difference: Decimal, comparedDay: Date) {
        self.difference = difference
        self.comparedDay = comparedDay
    }

    public var direction: ChangeDirection {
        if difference > 0 { return .up }
        if difference < 0 { return .down }
        return .same
    }
}

public struct FuelCost: Hashable, Sendable {
    public let amount: Decimal
    public let quantity: Decimal
    public let unit: QuantityUnit

    public init(amount: Decimal, quantity: Decimal, unit: QuantityUnit) {
        self.amount = amount
        self.quantity = quantity
        self.unit = unit
    }
}
