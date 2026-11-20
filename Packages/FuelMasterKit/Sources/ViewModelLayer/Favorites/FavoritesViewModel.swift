import DomainLayer
import Foundation
import Observation

public struct FavoriteRow: Sendable, Equatable, Identifiable {
    public let item: FavoriteSummary
    /// Nil until the station's province has loaded.
    public let hours: HoursSummary?

    public var id: StationID { item.id }
    public var summary: StationSummary? { item.summary }
    public var change: PriceChange? { item.change }
    /// The station is cached but doesn't sell the chosen product.
    public var isNotSold: Bool { item.station != nil && item.summary == nil }
}

public struct FavoritesContent: Sendable, Equatable {
    public let rows: [FavoriteRow]
    public let best: BestFavorite?
}

/// Favoritos (Bear note 07, section 5): the user's stations in their order, the cheapest one,
/// the change since yesterday, reorder and remove.
@MainActor @Observable
public final class FavoritesViewModel {
    public private(set) var product: Product = .diesel
    public private(set) var iCloudStatus: ICloudStatus = .syncDisabled
    /// True while any refresh runs. A count, so a pull to refresh that overlaps the automatic one
    /// doesn't clear the flag while the other is still loading.
    public var isRefreshing: Bool { refreshes > 0 }

    private var result: FavoritesResult?
    private var tankSize: Decimal = Settings.default.tankSize
    private var origin: Coordinate?
    /// Provinces already asked for in this run, so a failing one isn't retried in a loop.
    private var requestedProvinces: Set<ProvinceID> = []
    private var activeRuns = 0
    /// The stale-province refresh and yesterday's prices run once per visit, after the first result.
    private var didRefresh = false
    private var refreshes = 0
    @ObservationIgnored private var observation: Task<Void, Never>?
    /// Loading work the favourites stream asks for (the first refresh, missing provinces). It runs
    /// one job at a time in a task the view model owns, so it stops when Favoritos goes away and
    /// survives the observation restarting for a new fuel or position.
    @ObservationIgnored private var followUps: AsyncStream<FollowUp>.Continuation?
    @ObservationIgnored private var followUpWork: Task<Void, Never>?

    private let observeFavorites: ObserveFavorites
    private let toggleFavorite: ToggleFavorite
    private let reorderFavorites: ReorderFavorites
    private let observeICloudStatus: ObserveICloudStatus
    private let refreshPrices: RefreshPrices
    private let refreshFavorites: RefreshFavorites
    private let observeSettings: ObserveSettings
    private let locateUser: LocateUser
    private let format: DisplayFormat
    private let now: @Sendable () -> Date

    public init(observeFavorites: ObserveFavorites, toggleFavorite: ToggleFavorite, reorderFavorites: ReorderFavorites,
                observeICloudStatus: ObserveICloudStatus, refreshPrices: RefreshPrices, refreshFavorites: RefreshFavorites,
                observeSettings: ObserveSettings, locateUser: LocateUser,
                format: DisplayFormat = DisplayFormat(), now: @escaping @Sendable () -> Date = { .now }) {
        self.observeFavorites = observeFavorites
        self.toggleFavorite = toggleFavorite
        self.reorderFavorites = reorderFavorites
        self.observeICloudStatus = observeICloudStatus
        self.refreshPrices = refreshPrices
        self.refreshFavorites = refreshFavorites
        self.observeSettings = observeSettings
        self.locateUser = locateUser
        self.format = format
        self.now = now
    }

    // MARK: State

    public var state: ScreenState<FavoritesContent> {
        guard let result else { return .firstLoad }
        guard !result.items.isEmpty else { return .empty(.noFavorites) }
        let moment = now()
        let rows = result.items.map { item in
            FavoriteRow(item: item, hours: item.station.map {
                HoursText.summary(for: $0.hours, status: item.summary?.openingStatus ?? .unknown, at: moment, format: format)
            })
        }
        let content = FavoritesContent(rows: rows, best: result.best)
        return isRefreshing ? .updating(content) : .content(content)
    }

    // MARK: Intents

    /// Runs while Favoritos is on screen. Layout swaps overlap screens, so the last to leave tears down.
    public func start() async {
        activeRuns += 1
        if activeRuns == 1 { startFollowUps() }
        let settings = await observeSettings.current()
        product = settings.product
        tankSize = settings.tankSize
        observe()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.watchSettings() }
            group.addTask { await self.watchLocation() }
            group.addTask { await self.watchICloud() }
        }
        activeRuns -= 1
        guard activeRuns == 0 else { return }
        observation?.cancel()
        stopFollowUps()
        requestedProvinces = []
        didRefresh = false
    }

    /// Refreshes the favourites' stale provinces, then fetches yesterday for "cambio desde ayer".
    public func refresh(force: Bool = false) async {
        guard let provinces = await currentProvinces(), !provinces.isEmpty else { return }
        refreshes += 1
        requestedProvinces.formUnion(provinces)
        await refreshFavorites(provinces, product: product, force: force)
        refreshes -= 1
    }

    public func remove(_ id: StationID) async {
        guard let entry = result?.items.first(where: { $0.id == id })?.entry else { return }
        // Shown at once; the favourites stream confirms it.
        if let current = result {
            result = FavoritesResult(items: current.items.filter { $0.id != id }, best: current.best,
                                     missingProvinces: current.missingProvinces, freshness: current.freshness)
        }
        _ = try? await toggleFavorite(entry.stationID, province: entry.provinceID)
    }

    public func move(from source: Int, to destination: Int) async {
        guard var items = result?.items, items.indices.contains(source) else { return }
        let item = items.remove(at: source)
        items.insert(item, at: min(max(0, destination), items.count))
        if let current = result {
            result = FavoritesResult(items: items, best: current.best, missingProvinces: current.missingProvinces,
                                     freshness: current.freshness)
        }
        try? await reorderFavorites(from: source, to: destination)
    }

    // MARK: Loading

    private var request: FavoritesRequest {
        FavoritesRequest(product: product, tankSize: tankSize, origin: origin)
    }

    private func observe() {
        observation?.cancel()
        let request = request
        observation = Task { [observeFavorites] in
            for await next in observeFavorites(request) {
                guard !Task.isCancelled, request == self.request else { return }
                result = next
                if !didRefresh {
                    didRefresh = true
                    followUps?.yield(.refresh)
                } else {
                    followUps?.yield(.loadMissing(next.missingProvinces))
                }
            }
        }
    }

    /// A favourite outside the loaded provinces loads its province (note 06, Persistence).
    private func loadMissing(_ provinces: [ProvinceID]) async {
        let pending = provinces.filter { !requestedProvinces.contains($0) }
        guard !pending.isEmpty else { return }
        requestedProvinces.formUnion(pending)
        refreshes += 1
        _ = await refreshPrices(pending)
        refreshes -= 1
    }

    private enum FollowUp: Sendable {
        case refresh
        case loadMissing([ProvinceID])
    }

    private func startFollowUps() {
        let (stream, continuation) = AsyncStream<FollowUp>.makeStream()
        followUps = continuation
        followUpWork = Task {
            for await followUp in stream {
                guard !Task.isCancelled else { return }
                switch followUp {
                case .refresh: await refresh()
                case .loadMissing(let provinces): await loadMissing(provinces)
                }
            }
        }
    }

    private func stopFollowUps() {
        followUps?.finish()
        followUps = nil
        followUpWork?.cancel()
        followUpWork = nil
    }

    private func currentProvinces() async -> [ProvinceID]? {
        guard let result else { return nil }
        return Array(Set(result.items.map(\.entry.provinceID))).sorted()
    }

    private func watchSettings() async {
        for await settings in await observeSettings() where settings.product != product || settings.tankSize != tankSize {
            let productChanged = settings.product != product
            product = settings.product
            tankSize = settings.tankSize
            observe()
            if productChanged, let provinces = await currentProvinces() {
                await refreshFavorites.fetchYesterday(provinces, product: product)
            }
        }
    }

    private func watchLocation() async {
        guard await locateUser.status() == .authorized else { return }
        for await coordinate in await locateUser.updates() {
            if let origin, coordinate.distance(to: origin) < 200 { continue }
            origin = coordinate
            observe()
        }
    }

    private func watchICloud() async {
        for await status in await observeICloudStatus() { iCloudStatus = status }
    }
}
