import DomainLayer
import Foundation

/// The 7-day chart, ready to draw: one line for the station, a dashed one for the area average,
/// the axis days and the value range, all worked out once when the history changes.
public struct HistoryChart: Sendable, Equatable {
    /// A day with a price, as a number the chart can plot.
    public struct Point: Sendable, Equatable {
        public let day: Date
        public let amount: Double
    }

    public let history: PriceHistory
    /// The station's days that have a price, oldest first.
    public let stationPoints: [Point]
    /// The area average's days that have a value, oldest first.
    public let averagePoints: [Point]
    /// Padded so a flat line doesn't sit on the chart's edge.
    public let range: ClosedRange<Double>
    /// First, middle and last day of the window, as on the canvas ("14 oct · 17 oct · 20 oct").
    public let axisDays: [Date]
    public let isLoading: Bool
    /// The missing days couldn't be fetched (offline or the ministry is down).
    public let isIncomplete: Bool

    /// Nil when neither line has a single price to draw.
    init?(history: PriceHistory, isLoading: Bool, isIncomplete: Bool) {
        let station = Self.points(history.points)
        let average = Self.points(history.areaAverage)
        let amounts = (station + average).map(\.amount)
        guard let low = amounts.min(), let high = amounts.max() else { return nil }
        // At least 6 cents tall, the size of the price-level band, so small moves don't look dramatic.
        let padding = max(0.01, (0.06 - (high - low)) / 2)
        self.history = history
        stationPoints = station
        averagePoints = average
        range = (low - padding)...(high + padding)
        let days = history.points.map(\.day)
        axisDays = if let first = days.first, let last = days.last { [first, days[days.count / 2], last] } else { [] }
        self.isLoading = isLoading
        self.isIncomplete = isIncomplete
    }

    public var minimum: Decimal? { history.minimum }
    public var maximum: Decimal? { history.maximum }
    public var change: PriceChange? { history.change }
    public var hasStationPrices: Bool { !stationPoints.isEmpty }
    public var areaRange: (minimum: Decimal, maximum: Decimal)? {
        let amounts = history.areaAverage.compactMap(\.amount)
        guard let minimum = amounts.min(), let maximum = amounts.max() else { return nil }
        return (minimum, maximum)
    }

    private static func points(_ points: [HistoryPoint]) -> [Point] {
        points.compactMap { point in point.amount.map { Point(day: point.day, amount: NSDecimalNumber(decimal: $0).doubleValue) } }
    }
}
