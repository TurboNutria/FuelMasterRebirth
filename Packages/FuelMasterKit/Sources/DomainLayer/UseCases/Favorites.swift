import Foundation

/// One favourite in the user's order. `summary` is nil while its province isn't cached, or
/// when the station doesn't sell the chosen product.
public struct FavoriteSummary: Sendable, Equatable, Identifiable {
    public let entry: FavoriteEntry
    public let station: Station?
    public let summary: StationSummary?
    /// Today's price against yesterday's, when yesterday is in the history.
    public let change: PriceChange?

    public init(entry: FavoriteEntry, station: Station?, summary: StationSummary?, change: PriceChange?) {
        self.entry = entry
        self.station = station
        self.summary = summary
        self.change = change
    }

    public var id: StationID { entry.stationID }
}

/// "La más barata": the cheapest favourite and its full tank.
public struct BestFavorite: Sendable, Equatable {
    public let summary: StationSummary
    public let fuelCost: FuelCost?

    public init(summary: StationSummary, fuelCost: FuelCost?) {
        self.summary = summary
        self.fuelCost = fuelCost
    }
}

public struct FavoritesResult: Sendable, Equatable {
    public let items: [FavoriteSummary]
    public let best: BestFavorite?
    /// Provinces of favourites that aren't cached yet, so the caller can load them.
    public let missingProvinces: [ProvinceID]
    /// The oldest snapshot among the favourites' provinces.
    public let freshness: Freshness?

    public init(items: [FavoriteSummary], best: BestFavorite?, missingProvinces: [ProvinceID], freshness: Freshness?) {
        self.items = items
        self.best = best
        self.missingProvinces = missingProvinces
        self.freshness = freshness
    }

    public static let empty = FavoritesResult(items: [], best: nil, missingProvinces: [], freshness: nil)
}

public struct FavoritesRequest: Sendable, Equatable {
    public var product: Product
    public var tankSize: Decimal
    public var origin: Coordinate?

    public init(product: Product, tankSize: Decimal, origin: Coordinate? = nil) {
        self.product = product
        self.tankSize = tankSize
        self.origin = origin
    }
}

/// Favourites joined with current prices and the change since yesterday (Bear note 07,
/// ObserveFavorites). Re-emits when the favourites or the cache change.
public struct ObserveFavorites: Sendable {
    private let favorites: any FavoriteStationsRepository
    private let cache: any StationCacheRepository
    private let classify = ClassifyPrice()
    private let summarize = SummarizeArea()
    private let fuelCost = CalculateFuelCost()
    private let openingHours: EvaluateOpeningHours
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(favorites: any FavoriteStationsRepository, cache: any StationCacheRepository,
                openingHours: EvaluateOpeningHours = EvaluateOpeningHours(),
                timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid")!,
                now: @escaping @Sendable () -> Date = { .now }) {
        self.favorites = favorites
        self.cache = cache
        self.openingHours = openingHours
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.now = now
    }

    public func load(_ request: FavoritesRequest) async throws -> FavoritesResult {
        let entries = try await favorites.favorites()
        let provinces = Array(Set(entries.map(\.provinceID))).sorted()
        let stations = try await cache.stations(in: provinces)
        let byID = Dictionary(stations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let moment = now()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: moment))!

        var averages: [ProvinceID: Decimal] = [:]
        var freshness: Freshness?
        var missing: [ProvinceID] = []
        for province in provinces {
            let inProvince = stations.filter { $0.provinceID == province }
            averages[province] = summarize(inProvince, product: request.product, provinces: [province], snapshotDate: nil)?.average
            if let candidate = try await cache.freshness(of: province) {
                if freshness == nil || candidate.fetchedAt < freshness!.fetchedAt { freshness = candidate }
            } else {
                missing.append(province)
            }
        }

        var items: [FavoriteSummary] = []
        for entry in entries {
            guard let station = byID[entry.stationID] else {
                items.append(FavoriteSummary(entry: entry, station: nil, summary: nil, change: nil))
                continue
            }
            guard let price = station.price(for: request.product) else {
                items.append(FavoriteSummary(entry: entry, station: station, summary: nil, change: nil))
                continue
            }
            let summary = StationSummary(
                station: station, price: price,
                level: averages[station.provinceID].map { classify(price.amount, areaAverage: $0) } ?? .average,
                distance: request.origin.map { station.coordinate.distance(to: $0) },
                openingStatus: openingHours(station.hours, at: moment), isFavorite: true
            )
            let previous = try await cache.history(station: station.id, product: request.product, since: yesterday)
                .first { $0.day == yesterday }?.amount
            let change = previous.map { PriceChange(difference: price.amount - $0, comparedDay: yesterday) }
            items.append(FavoriteSummary(entry: entry, station: station, summary: summary, change: change))
        }

        let best = items.compactMap(\.summary).min { $0.price.amount < $1.price.amount }.map { cheapest in
            BestFavorite(summary: cheapest, fuelCost: fuelCost(price: cheapest.price, tankSize: request.tankSize))
        }
        return FavoritesResult(items: items, best: best, missingProvinces: missing, freshness: freshness)
    }

    public func callAsFunction(_ request: FavoritesRequest) -> AsyncStream<FavoritesResult> {
        AsyncStream { continuation in
            let task = Task {
                // Subscribe before the first read, so a change in between isn't missed.
                let favoriteChanges = await favorites.changes()
                let cacheChanges = await cache.changes()
                if let first = try? await load(request) { continuation.yield(first) }
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await _ in favoriteChanges {
                            if let next = try? await load(request) { continuation.yield(next) }
                        }
                    }
                    group.addTask {
                        for await _ in cacheChanges {
                            if let next = try? await load(request) { continuation.yield(next) }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Moves a favourite ("Mantén pulsado para reordenar").
public struct ReorderFavorites: Sendable {
    private let favorites: any FavoriteStationsRepository

    public init(favorites: any FavoriteStationsRepository) {
        self.favorites = favorites
    }

    public func callAsFunction(from source: Int, to destination: Int) async throws {
        try await favorites.move(from: source, to: destination)
    }
}

/// iCloud account status for the note under Favoritos.
public struct ObserveICloudStatus: Sendable {
    private let favorites: any FavoriteStationsRepository

    public init(favorites: any FavoriteStationsRepository) {
        self.favorites = favorites
    }

    public func callAsFunction() async -> AsyncStream<ICloudStatus> {
        await favorites.iCloudStatus()
    }
}
