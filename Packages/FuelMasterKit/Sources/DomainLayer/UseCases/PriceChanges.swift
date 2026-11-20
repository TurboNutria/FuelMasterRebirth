import Foundation

/// Today's price against yesterday's daily price ("↓ 0,020 €"), when yesterday is in the history.
/// The one rule behind Favoritos, the favourites widget and the Tent board.
struct ChangeSinceYesterday: Sendable {
    let cache: any StationCacheRepository
    let calendar: Calendar

    init(cache: any StationCacheRepository, timeZone: TimeZone) {
        self.cache = cache
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    func yesterday(at moment: Date) -> Date {
        calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: moment))!
    }

    func callAsFunction(_ price: Price, station: StationID, yesterday: Date) async throws -> PriceChange? {
        let previous = try await cache.history(station: station, product: price.product, since: yesterday)
            .first { $0.day == yesterday }?.amount
        return previous.map { PriceChange(difference: price.amount - $0, comparedDay: yesterday) }
    }
}

/// The change since yesterday for some of a station's fuels (the Tent board's arrows). Fetches
/// yesterday's prices for the station's province first when they're missing: one request per fuel.
public struct GetPriceChanges: Sendable {
    private let backfill: BackfillHistory
    private let sinceYesterday: ChangeSinceYesterday
    private let now: @Sendable () -> Date

    public init(cache: any StationCacheRepository, backfill: BackfillHistory,
                timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid")!,
                now: @escaping @Sendable () -> Date = { .now }) {
        self.backfill = backfill
        sinceYesterday = ChangeSinceYesterday(cache: cache, timeZone: timeZone)
        self.now = now
    }

    /// Fuels the station doesn't sell, or whose yesterday can't be fetched, are left out.
    public func callAsFunction(_ station: Station, products: [Product]) async -> [Product: PriceChange] {
        let yesterday = sinceYesterday.yesterday(at: now())
        var changes: [Product: PriceChange] = [:]
        for product in products {
            guard !Task.isCancelled else { break }
            guard let price = station.price(for: product) else { continue }
            _ = try? await backfill(province: station.provinceID, product: product, recentDays: 1)
            if let change = try? await sinceYesterday(price, station: station.id, yesterday: yesterday) {
                changes[product] = change
            }
        }
        return changes
    }
}

/// Brings Favoritos up to date: refreshes the favourites' provinces whose prices are stale, then
/// fetches yesterday's prices for "cambio desde ayer".
public struct RefreshFavorites: Sendable {
    private let refreshPrices: RefreshPrices
    private let backfill: BackfillHistory

    public init(refreshPrices: RefreshPrices, backfill: BackfillHistory) {
        self.refreshPrices = refreshPrices
        self.backfill = backfill
    }

    @discardableResult
    public func callAsFunction(_ provinces: [ProvinceID], product: Product, force: Bool = false) async -> RefreshOutcome {
        let outcome = await refreshPrices(provinces, force: force)
        await fetchYesterday(provinces, product: product)
        return outcome
    }

    /// Only yesterday's prices, after the fuel changes (today's are already cached for every fuel).
    public func fetchYesterday(_ provinces: [ProvinceID], product: Product) async {
        for province in provinces {
            guard !Task.isCancelled else { return }
            _ = try? await backfill(province: province, product: product, recentDays: 1)
        }
    }
}
