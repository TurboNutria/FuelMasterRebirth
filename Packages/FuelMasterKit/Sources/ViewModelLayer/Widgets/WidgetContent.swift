import DomainLayer
import Foundation

/// The URL a widget opens: `fuelmaster://station/3213` shows that station's detail.
public enum StationLink {
    public static let scheme = "fuelmaster"

    public static func url(for station: StationID) -> URL {
        URL(string: "\(scheme)://station/\(station.rawValue)")!
    }

    public static func station(from url: URL) -> StationID? {
        guard url.scheme == scheme, url.host() == "station" else { return nil }
        let id = url.pathComponents.dropFirst().first ?? ""
        return id.isEmpty ? nil : StationID(id)
    }
}

/// One station as a widget shows it.
public struct WidgetStation: Sendable, Equatable, Identifiable {
    public let id: StationID
    public let name: String
    public let brand: Brand?
    public let price: Decimal
    public let level: PriceLevel
    /// "1,4 km", when the last position is known.
    public let distance: String?
    /// Average minus price: positive is below the average (the small widget's second line).
    public let belowAverage: Decimal?
    /// Today against yesterday (the favourites widget).
    public let change: PriceChange?
    public let link: URL
}

/// Everything a widget draws for one timeline entry, already decided: which stations, whether
/// the prices are too old, and where the price falls in the area's range.
public struct WidgetContent: Sendable, Equatable {
    /// Prices fetched longer ago than this are dimmed, with their age in red (Bear note 06).
    public static let staleAfter: TimeInterval = 60 * 60

    public let product: Product
    public let priceScale: PriceScale
    public let accent: AccentChoice
    public let cheapest: WidgetStation?
    public let favorites: [WidgetStation]
    /// Cheapest and most expensive in the area, for the Lock Screen gauge.
    public let range: ClosedRange<Decimal>?
    /// "Hace 3 h" when the area's prices are stale; nil while they're fresh.
    public let staleAge: String?
    public let favoritesStaleAge: String?

    public init(product: Product, priceScale: PriceScale, accent: AccentChoice = .preset(.orange),
                cheapest: WidgetStation?, favorites: [WidgetStation],
                range: ClosedRange<Decimal>?, staleAge: String?, favoritesStaleAge: String?) {
        self.product = product
        self.priceScale = priceScale
        self.accent = accent
        self.cheapest = cheapest
        self.favorites = favorites
        self.range = range
        self.staleAge = staleAge
        self.favoritesStaleAge = favoritesStaleAge
    }

    public init(_ snapshot: WidgetSnapshot, at date: Date, format: DisplayFormat = DisplayFormat()) {
        func station(_ summary: StationSummary, change: PriceChange?) -> WidgetStation {
            WidgetStation(
                id: summary.id, name: summary.station.name, brand: summary.station.brand,
                price: summary.price.amount, level: summary.level,
                distance: summary.distance.map { format.distance(meters: $0) },
                belowAverage: snapshot.summary.map { $0.average - summary.price.amount },
                change: change, link: StationLink.url(for: summary.id)
            )
        }
        func staleAge(_ freshness: Freshness?) -> String? {
            guard let fetched = freshness?.fetchedAt, date.timeIntervalSince(fetched) > Self.staleAfter else { return nil }
            return format.relativeTime(fetched, now: date)
        }
        product = snapshot.product
        priceScale = snapshot.priceScale
        accent = snapshot.accent
        cheapest = snapshot.cheapest.map { station($0, change: nil) }
        favorites = snapshot.favorites.compactMap { item in item.summary.map { station($0, change: item.change) } }
        range = snapshot.summary.map { $0.minimum...$0.maximum }
        self.staleAge = staleAge(snapshot.freshness)
        favoritesStaleAge = staleAge(snapshot.favoritesFreshness)
    }

    /// Where the cheapest price sits between the area's minimum (0) and maximum (1).
    public var gaugeFraction: Double? {
        guard let cheapest, let range else { return nil }
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let fraction = NSDecimalNumber(decimal: (cheapest.price - range.lowerBound) / span).doubleValue
        return min(max(fraction, 0), 1)
    }

    /// When the timeline should redraw on its own: the moment the shown prices turn stale.
    public static func staleDate(of snapshot: WidgetSnapshot) -> Date? {
        [snapshot.freshness, snapshot.favoritesFreshness].compactMap { $0?.fetchedAt }.min()?
            .addingTimeInterval(staleAfter + 1)
    }

    /// Made-up content for the widget gallery and placeholders.
    public static let sample: WidgetContent = {
        func station(_ id: String, _ name: String, _ brand: Brand?, _ price: String, _ level: PriceLevel,
                     _ meters: Double, change: String?) -> WidgetStation {
            WidgetStation(id: StationID(id), name: name, brand: brand, price: Decimal(string: price)!, level: level,
                          distance: DisplayFormat().distance(meters: meters), belowAverage: Decimal(string: "0.065"),
                          change: change.map { PriceChange(difference: Decimal(string: $0)!, comparedDay: .now) },
                          link: StationLink.url(for: StationID(id)))
        }
        let ballenoil = station("3213", "Ballenoil", .ballenoil, "1.859", .cheap, 1400, change: "0")
        return WidgetContent(
            product: .diesel, priceScale: .trafficLight, cheapest: ballenoil,
            favorites: [
                ballenoil,
                station("2909", "Shell Goya", .shell, "1.934", .average, 2000, change: "-0.005"),
                station("4710", "Repsol Cea Bermúdez", .repsol, "1.979", .average, 2500, change: "-0.020"),
            ],
            range: Decimal(string: "1.739")!...Decimal(string: "2.049")!, staleAge: nil, favoritesStaleAge: nil
        )
    }()
}
