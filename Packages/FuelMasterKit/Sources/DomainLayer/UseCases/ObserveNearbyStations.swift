import Foundation

public enum StationSort: Sendable, Equatable {
    case cheapest
    case nearest
}

public enum NearbyArea: Sendable, Equatable {
    /// Around a point (the list): stations within `radius` metres.
    case radius(center: Coordinate, meters: Double)
    /// What the map shows.
    case bounds(BoundingBox)
}

public struct NearbyRequest: Sendable, Equatable {
    public var provinces: [ProvinceID]
    public var area: NearbyArea
    public var product: Product
    public var sort: StationSort
    /// Empty means all levels.
    public var levels: Set<PriceLevel>
    /// The user's position, for distances. Optional when location is denied.
    public var origin: Coordinate?

    public init(provinces: [ProvinceID], area: NearbyArea, product: Product, sort: StationSort = .cheapest,
                levels: Set<PriceLevel> = [], origin: Coordinate? = nil) {
        self.provinces = provinces
        self.area = area
        self.product = product
        self.sort = sort
        self.levels = levels
        self.origin = origin
    }
}

public struct NearbyResult: Sendable, Equatable {
    public let stations: [StationSummary]
    /// Average, min and max across the loaded provinces (not just the visible area).
    public let summary: AreaPriceSummary?
    public let freshness: Freshness?
    /// The products at least one station in the requested area sells, whatever the request's
    /// product and levels: the fuel menus offer only these.
    public let availableProducts: Set<Product>

    public init(stations: [StationSummary], summary: AreaPriceSummary?, freshness: Freshness?,
                availableProducts: Set<Product> = []) {
        self.stations = stations
        self.summary = summary
        self.freshness = freshness
        self.availableProducts = availableProducts
    }

    public static let empty = NearbyResult(stations: [], summary: nil, freshness: nil)
}

/// Nearby stations from the cache, re-emitted whenever the cache or the favourites change.
public struct ObserveNearbyStations: Sendable {
    private let cache: any StationCacheRepository
    private let favorites: any FavoriteStationsRepository
    private let classify = ClassifyPrice()
    private let summarize = SummarizeArea()
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

    /// One-off read of the cache.
    public func load(_ request: NearbyRequest) async throws -> NearbyResult {
        let stations = try await cache.stations(in: request.provinces)
        let favoriteIDs = Set(try await favorites.favorites().map(\.stationID))
        var freshness: Freshness?
        for province in request.provinces {
            guard let candidate = try await cache.freshness(of: province) else { continue }
            // The oldest province decides how fresh the whole result is.
            if freshness == nil || candidate.fetchedAt < freshness!.fetchedAt { freshness = candidate }
        }
        return build(request, stations: stations, favorites: favoriteIDs, freshness: freshness)
    }

    /// Emits a new result whenever the cache or the favourites change.
    public func callAsFunction(_ request: NearbyRequest) -> AsyncStream<NearbyResult> {
        AsyncStream { continuation in
            let task = Task {
                // Subscribe before the first read, so a province saved in between isn't missed.
                let cacheChanges = await cache.changes()
                let favoriteChanges = await favorites.changes()
                if let first = try? await load(request) { continuation.yield(first) }
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await _ in cacheChanges {
                            if let next = try? await load(request) { continuation.yield(next) }
                        }
                    }
                    group.addTask {
                        for await _ in favoriteChanges {
                            if let next = try? await load(request) { continuation.yield(next) }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func build(_ request: NearbyRequest, stations: [Station], favorites: Set<StationID>,
               freshness: Freshness?) -> NearbyResult {
        let summary = summarize(stations, product: request.product, provinces: request.provinces,
                                snapshotDate: freshness?.snapshotDate)
        let moment = now()
        var summaries: [StationSummary] = []
        var available: Set<Product> = []
        for station in stations {
            switch request.area {
            case .bounds(let box):
                guard box.contains(station.coordinate) else { continue }
            case .radius(let center, let meters):
                guard station.coordinate.distance(to: center) <= meters else { continue }
            }
            available.formUnion(station.prices.keys)
            guard let price = station.price(for: request.product) else { continue }
            let level = summary.map { classify(price.amount, areaAverage: $0.average) } ?? .average
            guard request.levels.isEmpty || request.levels.contains(level) else { continue }
            summaries.append(StationSummary(
                station: station, price: price, level: level,
                distance: request.origin.map { station.coordinate.distance(to: $0) },
                openingStatus: openingHours(station.hours, at: moment),
                isFavorite: favorites.contains(station.id)
            ))
        }
        summaries.sort { lhs, rhs in
            switch request.sort {
            case .cheapest:
                if lhs.price.amount != rhs.price.amount { return lhs.price.amount < rhs.price.amount }
                return (lhs.distance ?? .infinity) < (rhs.distance ?? .infinity)
            case .nearest:
                return (lhs.distance ?? .infinity) < (rhs.distance ?? .infinity)
            }
        }
        return NearbyResult(stations: summaries, summary: summary, freshness: freshness, availableProducts: available)
    }
}
