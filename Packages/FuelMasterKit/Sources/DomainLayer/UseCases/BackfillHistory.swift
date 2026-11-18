import Foundation

/// Fills in the last days of daily history for a province and product, then drops older days.
public struct BackfillHistory: Sendable {
    public static let days = 7

    private let remote: any StationRemoteRepository
    private let cache: any StationCacheRepository
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(remote: any StationRemoteRepository, cache: any StationCacheRepository,
                timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid")!,
                now: @escaping @Sendable () -> Date = { .now }) {
        self.remote = remote
        self.cache = cache
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.now = now
    }

    /// The past `days` days, oldest first, not including today (today comes from current prices).
    public func window() -> [Date] {
        let today = calendar.startOfDay(for: now())
        return (1...Self.days).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    /// Returns how many days were fetched. `recentDays` limits the fetch to the latest days
    /// (Favoritos only needs yesterday), while older days are still trimmed.
    @discardableResult
    public func callAsFunction(province: ProvinceID, product: Product, recentDays: Int = Self.days) async throws -> Int {
        let days = window()
        guard let oldest = days.first else { return 0 }
        let known = try await cache.historyDays(province: province, product: product, since: oldest)
        var fetched = 0
        for day in days.suffix(recentDays) where !known.contains(day) {
            let snapshot = try await remote.history(province: province, product: product, day: day)
            try await cache.save(snapshot)
            fetched += 1
        }
        try await cache.deleteHistory(before: oldest)
        return fetched
    }
}
