import Foundation

/// Everything the detail screen shows about one station for the chosen product.
public struct StationDetail: Sendable, Equatable {
    public let station: Station
    /// Nil when the station doesn't sell the chosen product.
    public let price: Price?
    public let level: PriceLevel?
    /// Average of the product across the station's province ("Media de Madrid").
    public let areaAverage: Decimal?
    /// The station's other products, in the fuel picker's order.
    public let otherPrices: [Price]
    public let openingStatus: OpeningStatus
    public let fuelCost: FuelCost?
    /// The same tank at the area average, for "Ahorras 3,58 € frente a la media".
    public let averageFuelCost: FuelCost?
    public let distance: Double?
    public let isFavorite: Bool
    public let freshness: Freshness?

    public init(station: Station, price: Price?, level: PriceLevel?, areaAverage: Decimal?, otherPrices: [Price],
                openingStatus: OpeningStatus, fuelCost: FuelCost?, averageFuelCost: FuelCost?, distance: Double?,
                isFavorite: Bool, freshness: Freshness?) {
        self.station = station
        self.price = price
        self.level = level
        self.areaAverage = areaAverage
        self.otherPrices = otherPrices
        self.openingStatus = openingStatus
        self.fuelCost = fuelCost
        self.averageFuelCost = averageFuelCost
        self.distance = distance
        self.isFavorite = isFavorite
        self.freshness = freshness
    }

    /// Average minus price: positive means below the average.
    public var belowAverage: Decimal? {
        guard let price, let areaAverage else { return nil }
        return areaAverage - price.amount
    }

    /// Positive when a full tank here costs less than at the average price. Worked out from the
    /// unrounded gap, so 0,065 € × 55 l reads 3,58 € rather than the difference of two rounded totals.
    public var tankSaving: Decimal? {
        guard let fuelCost, averageFuelCost != nil, let belowAverage else { return nil }
        var saving = belowAverage * fuelCost.quantity
        var rounded = Decimal()
        NSDecimalRound(&rounded, &saving, 2, .plain)
        return rounded
    }
}

public struct StationDetailRequest: Sendable, Equatable {
    public var stationID: StationID
    public var product: Product
    public var tankSize: Decimal
    /// The user's position, for the distance.
    public var origin: Coordinate?

    public init(stationID: StationID, product: Product, tankSize: Decimal, origin: Coordinate? = nil) {
        self.stationID = stationID
        self.product = product
        self.tankSize = tankSize
        self.origin = origin
    }
}

/// One station from the cache with its price against the area, tank cost and other fuels
/// (Bear note 07, GetStationDetail). Re-emits when the cache or the favourites change.
public struct GetStationDetail: Sendable {
    private let cache: any StationCacheRepository
    private let favorites: any FavoriteStationsRepository
    private let classify = ClassifyPrice()
    private let summarize = SummarizeArea()
    private let fuelCost = CalculateFuelCost()
    private let openingHours: EvaluateOpeningHours
    private let now: @Sendable () -> Date

    public init(cache: any StationCacheRepository, favorites: any FavoriteStationsRepository,
                openingHours: EvaluateOpeningHours = EvaluateOpeningHours(),
                now: @escaping @Sendable () -> Date = { .now }) {
        self.cache = cache
        self.favorites = favorites
        self.openingHours = openingHours
        self.now = now
    }

    /// Nil when the station isn't in the cache (its province hasn't been loaded).
    public func load(_ request: StationDetailRequest) async throws -> StationDetail? {
        guard let station = try await cache.station(id: request.stationID) else { return nil }
        let neighbours = try await cache.stations(in: [station.provinceID])
        let freshness = try await cache.freshness(of: station.provinceID)
        let isFavorite = try await favorites.favorites().contains { $0.stationID == station.id }
        let average = summarize(neighbours, product: request.product, provinces: [station.provinceID],
                                snapshotDate: freshness?.snapshotDate)?.average
        let price = station.price(for: request.product)
        let averagePrice = average.map { Price(amount: $0, product: request.product) }
        return StationDetail(
            station: station,
            price: price,
            level: price.flatMap { price in average.map { classify(price.amount, areaAverage: $0) } },
            areaAverage: average,
            otherPrices: Product.allCases.filter { $0 != request.product }.compactMap { station.price(for: $0) },
            openingStatus: openingHours(station.hours, at: now()),
            fuelCost: price.flatMap { fuelCost(price: $0, tankSize: request.tankSize) },
            averageFuelCost: price == nil ? nil : averagePrice.flatMap { fuelCost(price: $0, tankSize: request.tankSize) },
            distance: request.origin.map { station.coordinate.distance(to: $0) },
            isFavorite: isFavorite,
            freshness: freshness
        )
    }

    /// The detail now, then again whenever the cache or the favourites change.
    public func callAsFunction(_ request: StationDetailRequest) -> AsyncStream<StationDetail?> {
        AsyncStream { continuation in
            let task = Task {
                // Subscribe before the first read, so a province saved in between isn't missed.
                let cacheChanges = await cache.changes()
                let favoriteChanges = await favorites.changes()
                continuation.yield(try? await load(request))
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await _ in cacheChanges { continuation.yield(try? await load(request)) }
                    }
                    group.addTask {
                        for await _ in favoriteChanges { continuation.yield(try? await load(request)) }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// The last 7 days of a station's price next to its province's average (Bear note 07,
/// GetPriceHistory). Today comes from the current prices; earlier days from the daily history,
/// which is backfilled when days are missing.
public struct GetPriceHistory: Sendable {
    public static let days = 7

    private let cache: any StationCacheRepository
    private let backfill: BackfillHistory
    private let summarize = SummarizeArea()
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(cache: any StationCacheRepository, backfill: BackfillHistory,
                timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid")!,
                now: @escaping @Sendable () -> Date = { .now }) {
        self.cache = cache
        self.backfill = backfill
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.now = now
    }

    /// The 7 days shown, oldest first, ending today.
    public func window() -> [Date] {
        let today = calendar.startOfDay(for: now())
        return (0..<Self.days).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    /// What the cache has now, with nil for missing days. Nil when the station isn't cached.
    public func cached(station id: StationID, product: Product) async throws -> PriceHistory? {
        guard let station = try await cache.station(id: id) else { return nil }
        let days = window()
        guard let oldest = days.first, let today = days.last else { return nil }
        let own = Dictionary(try await cache.history(station: id, product: product, since: oldest).map { ($0.day, $0.amount) },
                             uniquingKeysWith: { first, _ in first })
        let area = Dictionary(try await cache.areaHistory(provinces: [station.provinceID], product: product, since: oldest)
                                .map { ($0.day, $0.amount) },
                              uniquingKeysWith: { first, _ in first })
        let neighbours = try await cache.stations(in: [station.provinceID])
        let todayAverage = summarize(neighbours, product: product, provinces: [station.provinceID], snapshotDate: nil)?.average

        let points = days.map { day in
            HistoryPoint(day: day, amount: day == today ? station.price(for: product)?.amount : own[day] ?? nil)
        }
        let averages = days.map { day in
            HistoryPoint(day: day, amount: day == today ? todayAverage : area[day] ?? nil)
        }
        return PriceHistory(stationID: id, product: product, points: points, areaAverage: averages)
    }

    /// Fetches the province's missing days first, then reads the cache. Throws when the fetch
    /// fails (offline), so the caller can keep showing what `cached` returned.
    public func callAsFunction(station id: StationID, product: Product) async throws -> PriceHistory? {
        guard let station = try await cache.station(id: id) else { return nil }
        try await backfill(province: station.provinceID, product: product)
        return try await cached(station: id, product: product)
    }
}

/// Adds or removes a favourite and reports whether it's a favourite now.
public struct ToggleFavorite: Sendable {
    private let favorites: any FavoriteStationsRepository

    public init(favorites: any FavoriteStationsRepository) {
        self.favorites = favorites
    }

    @discardableResult
    public func callAsFunction(_ station: StationID, province: ProvinceID) async throws -> Bool {
        if try await favorites.favorites().contains(where: { $0.stationID == station }) {
            try await favorites.remove(station)
            return false
        }
        try await favorites.add(station, province: province)
        return true
    }
}
