import DomainLayer
import Foundation
import OSLog

/// The watch's settings and favourites (Bear note 06, "iPhone ↔ watch sync"): a copy of what the
/// iPhone last sent, kept on the watch so it works with the phone away. Changes made on the watch
/// apply at once and go to the iPhone as requests; the iPhone's next context confirms them.
/// Implements the same protocols as the iPhone's repositories, so the use cases don't change.
public actor CompanionMirrorRepository: SettingsRepository, FavoriteStationsRepository {
    struct Stored: Codable, Equatable {
        var settings: DomainLayer.Settings
        var productChangedAt: Date
        var favorites: [CompanionFavorite]
    }

    private let session: any CompanionSession
    private let defaults: UserDefaultsBox
    private let now: @Sendable () -> Date
    private var stored: Stored
    private let settingsChanges = Broadcaster<DomainLayer.Settings>()
    private let favoriteChanges = Broadcaster<[FavoriteEntry]>()

    static let storageKey = "companion.mirror.v1"

    /// The watch has no onboarding: it starts from the defaults until the iPhone's context arrives.
    static let initial = Stored(
        settings: {
            var settings = DomainLayer.Settings.default
            settings.onboardingCompleted = true
            return settings
        }(),
        productChangedAt: .distantPast,
        favorites: []
    )

    public init(session: any CompanionSession, defaults: UserDefaults = .standard,
                now: @escaping @Sendable () -> Date = { .now }) {
        self.session = session
        self.defaults = UserDefaultsBox(defaults)
        self.now = now
        stored = defaults.data(forKey: Self.storageKey)
            .flatMap { CompanionCoding.decode(Stored.self, from: $0) } ?? Self.initial
    }

    /// Runs while the app is open: applies the last context delivered (also while the app was
    /// closed), then each new one.
    public func run() async {
        let contexts = await session.receivedContexts()
        await session.activate()
        if let data = await session.latestReceivedContext() { await receive(data) }
        for await data in contexts { await receive(data) }
    }

    func receive(_ data: Data) async {
        guard let context = CompanionCoding.decode(CompanionContext.self, from: data) else { return }
        await apply(context)
    }

    func apply(_ context: CompanionContext) async {
        var next = stored
        next.settings.accent = context.accent
        next.settings.priceScale = context.priceScale
        next.settings.defaultProvinceID = context.defaultProvinceID
        // The watch remembers its own area; the iPhone's is only a starting point.
        next.settings.lastViewedProvinceID = next.settings.lastViewedProvinceID ?? context.lastViewedProvinceID
        next.settings.lastLocation = next.settings.lastLocation ?? context.lastLocation
        if context.productChangedAt >= next.productChangedAt {
            next.settings.product = context.product
            next.productChangedAt = context.productChangedAt
        }
        next.favorites = context.favorites
        save(next)
        Logger.companion.info("Context from the iPhone: \(next.settings.product.rawValue), \(next.favorites.count) favourites")
    }

    // MARK: - SettingsRepository

    public func current() async -> DomainLayer.Settings {
        stored.settings
    }

    /// Saves before telling the iPhone: nothing is awaited between reading `stored` and writing it,
    /// so a context that arrives meanwhile can't be overwritten with an older copy.
    @discardableResult
    public func update(_ change: @Sendable (inout DomainLayer.Settings) -> Void) async -> DomainLayer.Settings {
        var next = stored
        change(&next.settings)
        let productChanged = next.settings.product != stored.settings.product
        if productChanged { next.productChangedAt = now() }
        save(next)
        if productChanged { await send(.setProduct(next.settings.product, changedAt: next.productChangedAt)) }
        return next.settings
    }

    public func changes() async -> AsyncStream<DomainLayer.Settings> {
        settingsChanges.stream()
    }

    // MARK: - FavoriteStationsRepository

    public func favorites() async throws -> [FavoriteEntry] {
        entries(stored.favorites)
    }

    public func add(_ station: StationID, province: ProvinceID) async throws {
        guard !stored.favorites.contains(where: { $0.stationID == station }) else { return }
        var next = stored
        next.favorites.append(CompanionFavorite(stationID: station, provinceID: province))
        save(next)
        await send(.addFavorite(station, province: province))
    }

    public func remove(_ station: StationID) async throws {
        guard stored.favorites.contains(where: { $0.stationID == station }) else { return }
        var next = stored
        next.favorites.removeAll { $0.stationID == station }
        save(next)
        await send(.removeFavorite(station))
    }

    /// The watch has no reordering; the iPhone's order comes back with its next context anyway.
    public func move(from source: Int, to destination: Int) async throws {
        guard stored.favorites.indices.contains(source) else { return }
        var next = stored
        let item = next.favorites.remove(at: source)
        next.favorites.insert(item, at: min(max(0, destination), next.favorites.count))
        save(next)
    }

    public func changes() async -> AsyncStream<[FavoriteEntry]> {
        favoriteChanges.stream()
    }

    /// Favourites sync through the iPhone, not iCloud.
    public func iCloudStatus() async -> AsyncStream<ICloudStatus> {
        AsyncStream { continuation in
            continuation.yield(.syncDisabled)
            continuation.finish()
        }
    }

    // MARK: - Storage

    /// Synchronous, so the read of `stored` and the write can't be split by another call.
    private func save(_ next: Stored) {
        let previous = stored
        guard next != previous else { return }
        stored = next
        if let data = CompanionCoding.encode(next) { defaults.value.set(data, forKey: Self.storageKey) }
        if next.settings != previous.settings { settingsChanges.send(next.settings) }
        if next.favorites != previous.favorites { favoriteChanges.send(entries(next.favorites)) }
    }

    private func send(_ request: CompanionRequest) async {
        guard let data = CompanionCoding.encode(request) else { return }
        await session.send(request: data)
    }

    private func entries(_ favorites: [CompanionFavorite]) -> [FavoriteEntry] {
        favorites.enumerated().map { index, favorite in
            FavoriteEntry(stationID: favorite.stationID, provinceID: favorite.provinceID, order: index)
        }
    }
}
