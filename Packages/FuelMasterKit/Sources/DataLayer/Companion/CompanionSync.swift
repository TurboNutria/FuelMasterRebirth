import DomainLayer
import Foundation
import OSLog

/// The iPhone side of the watch sync (Bear note 06): sends the watch the fuel, look, area and
/// favourites whenever they change, and applies what the watch asks for (a favourite added or
/// removed, a new fuel). The iPhone's repositories stay the source of truth.
public actor CompanionSync {
    private let session: any CompanionSession
    private let settings: any SettingsRepository
    private let favorites: any FavoriteStationsRepository
    private let defaults: UserDefaultsBox
    private let now: @Sendable () -> Date
    private var lastSent: CompanionContext?
    private var isSending = false
    private var needsSend = false

    static let productKey = "companion.product"
    static let productChangedAtKey = "companion.productChangedAt"

    public init(session: any CompanionSession, settings: any SettingsRepository,
                favorites: any FavoriteStationsRepository, defaults: UserDefaults = .standard,
                now: @escaping @Sendable () -> Date = { .now }) {
        self.session = session
        self.settings = settings
        self.favorites = favorites
        self.defaults = UserDefaultsBox(defaults)
        self.now = now
    }

    /// Runs while the app is open. Requests the watch queued while the iPhone app was closed
    /// arrive once it activates.
    public func run() async {
        let settingsChanges = await settings.changes()
        let favoriteChanges = await favorites.changes()
        let requests = await session.receivedRequests()
        await session.activate()
        await sendContext()
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await changed in settingsChanges { await self.settingsChanged(changed) }
            }
            group.addTask {
                for await _ in favoriteChanges { await self.sendContext() }
            }
            group.addTask {
                for await data in requests {
                    guard let request = CompanionCoding.decode(CompanionRequest.self, from: data) else { continue }
                    await self.handle(request)
                }
            }
        }
    }

    func handle(_ request: CompanionRequest) async {
        Logger.companion.info("Request from the watch: \(String(describing: request), privacy: .public)")
        switch request {
        case .addFavorite(let station, let province):
            try? await favorites.add(station, province: province)
        case .removeFavorite(let station):
            try? await favorites.remove(station)
        case .setProduct(let product, let changedAt):
            // A change the iPhone made after this one wins; the watch already has it.
            guard changedAt > productChangedAt() else { return }
            record(product, changedAt: changedAt)
            await settings.update { $0.product = product }
        }
    }

    /// Sends the latest fuel, look, area and favourites. Calls that arrive while a send is under
    /// way are folded into one more pass, so the last context sent is always built from state
    /// read after the last change. (Two overlapping builds could otherwise finish out of order and
    /// leave the watch on the older one.)
    func sendContext() async {
        needsSend = true
        guard !isSending else { return }
        isSending = true
        while needsSend {
            needsSend = false
            await buildAndSendContext()
        }
        isSending = false
    }

    private func buildAndSendContext() async {
        let current = await settings.current()
        switch storedProduct() {
        // First sight of the fuel on this install: not a change by the user.
        case nil: record(current.product, changedAt: .distantPast)
        case let stored? where stored != current.product: record(current.product, changedAt: now())
        default: break
        }
        let entries = (try? await favorites.favorites()) ?? []
        let context = CompanionContext(
            product: current.product, productChangedAt: productChangedAt(), accent: current.accent,
            priceScale: current.priceScale, defaultProvinceID: current.defaultProvinceID,
            lastViewedProvinceID: current.lastViewedProvinceID, lastLocation: current.lastLocation,
            favorites: entries.map { CompanionFavorite(stationID: $0.stationID, provinceID: $0.provinceID) }
        )
        guard context != lastSent, let data = CompanionCoding.encode(context) else { return }
        lastSent = context
        Logger.companion.info("Context to the watch: \(context.product.rawValue), \(context.favorites.count) favourites")
        await session.send(context: data)
    }

    func settingsChanged(_ changed: DomainLayer.Settings) async {
        if let stored = storedProduct(), stored != changed.product { record(changed.product, changedAt: now()) }
        await sendContext()
    }

    // MARK: - When the fuel changed

    /// Never changed (a fresh install) counts as the distant past, so the watch's choice wins.
    private func productChangedAt() -> Date {
        defaults.value.object(forKey: Self.productChangedAtKey) as? Date ?? .distantPast
    }

    private func storedProduct() -> Product? {
        guard defaults.value.object(forKey: Self.productKey) != nil else { return nil }
        return Product(rawValue: defaults.value.integer(forKey: Self.productKey))
    }

    private func record(_ product: Product, changedAt: Date) {
        defaults.value.set(product.rawValue, forKey: Self.productKey)
        defaults.value.set(changedAt, forKey: Self.productChangedAtKey)
    }
}

/// `UserDefaults` is thread-safe but not marked `Sendable`.
struct UserDefaultsBox: @unchecked Sendable {
    let value: UserDefaults
    init(_ value: UserDefaults) { self.value = value }
}
