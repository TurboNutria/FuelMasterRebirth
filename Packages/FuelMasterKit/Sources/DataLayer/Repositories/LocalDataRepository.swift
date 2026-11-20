import DomainLayer
import Foundation
import SwiftData
import Synchronization

/// Everything stored or bundled on the device: the price cache and history (SwiftData),
/// province outlines and municipalities (bundled JSON), and per-device settings (App Group defaults).
public final class LocalDataRepository: StationCacheRepository, ProvinceRepository, SettingsRepository {
    private let store: CacheStore
    private let geography: GeographyStore
    private let defaults: UserDefaultsBox
    private let cacheChanges = Broadcaster<Void>()
    private let settingsChanges = Broadcaster<DomainLayer.Settings>()
    /// Serialises settings writes, so two changes made at once can't undo each other.
    private let settingsLock = Mutex(())

    static let settingsKey = "settings.v1"

    public init(container: ModelContainer, defaults: UserDefaults = .standard) {
        store = CacheStore(modelContainer: container)
        geography = .bundled()
        self.defaults = UserDefaultsBox(defaults)
    }

    // MARK: - StationCacheRepository

    public func stations(in provinces: [ProvinceID]) async throws -> [Station] {
        try await store.stations(in: provinces)
    }

    public func station(id: StationID) async throws -> Station? {
        try await store.station(id: id)
    }

    public func save(_ snapshot: ProvinceSnapshot, fetchedAt: Date) async throws {
        try await store.save(snapshot, fetchedAt: fetchedAt)
        cacheChanges.send(())
    }

    public func freshness(of province: ProvinceID) async throws -> Freshness? {
        try await store.freshness(of: province)
    }

    public func history(station: StationID, product: Product, since day: Date) async throws -> [HistoryPoint] {
        try await store.history(station: station, product: product, since: day)
    }

    public func areaHistory(provinces: [ProvinceID], product: Product, since day: Date) async throws -> [HistoryPoint] {
        try await store.areaHistory(provinces: provinces, product: product, since: day)
    }

    public func historyDays(province: ProvinceID, product: Product, since day: Date) async throws -> Set<Date> {
        try await store.historyDays(province: province, product: product, since: day)
    }

    public func save(_ history: HistorySnapshot) async throws {
        try await store.save(history)
        cacheChanges.send(())
    }

    public func deleteHistory(before day: Date) async throws {
        try await store.deleteHistory(before: day)
    }

    public func changes() async -> AsyncStream<Void> {
        cacheChanges.stream()
    }

    // MARK: - ProvinceRepository

    public func allProvinces() async -> [Province] { geography.provinces }

    public func province(at coordinate: Coordinate) async -> ProvinceID? { geography.province(at: coordinate) }

    public func provinces(intersecting bounds: BoundingBox) async -> [ProvinceID] {
        geography.provinces(intersecting: bounds)
    }

    public func municipalities(matching text: String) async -> [Municipality] {
        geography.municipalities(matching: text)
    }

    // MARK: - SettingsRepository

    public func current() async -> DomainLayer.Settings {
        settingsLock.withLock { _ in storedSettings() }
    }

    /// Reads, changes, saves and publishes under one lock, so a change made at the same time by
    /// another caller is never overwritten and observers see the changes in order.
    @discardableResult
    public func update(_ change: @Sendable (inout DomainLayer.Settings) -> Void) async -> DomainLayer.Settings {
        settingsLock.withLock { _ in
            let current = storedSettings()
            var next = current
            change(&next)
            guard next != current else { return current }
            if let data = try? JSONEncoder().encode(next) {
                defaults.value.set(data, forKey: Self.settingsKey)
            }
            settingsChanges.send(next)
            return next
        }
    }

    public func changes() async -> AsyncStream<DomainLayer.Settings> {
        settingsChanges.stream()
    }

    private func storedSettings() -> DomainLayer.Settings {
        guard let data = defaults.value.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(DomainLayer.Settings.self, from: data) else { return .default }
        return settings
    }
}
