import DomainLayer
import Foundation
import Observation

/// What the list header says about the area: "Cerca de ti · 3 km" or, without location, the
/// default province ("En Madrid").
public enum ListScope: Sendable, Equatable {
    case nearby(radius: Double)
    case province(name: String)
}

/// The price-level chips: Todas / Baratas / Medias / Caras.
public enum LevelFilter: String, CaseIterable, Sendable {
    case all, cheap, average, expensive

    var levels: Set<PriceLevel> {
        switch self {
        case .all: []
        case .cheap: [.cheap]
        case .average: [.average]
        case .expensive: [.expensive]
        }
    }

    var level: PriceLevel? {
        switch self {
        case .all: nil
        case .cheap: .cheap
        case .average: .average
        case .expensive: .expensive
        }
    }
}

public struct StationListRow: Sendable, Equatable, Identifiable {
    public let summary: StationSummary
    public let hours: HoursSummary
    public var id: StationID { summary.id }
}

public struct StationListContent: Sendable, Equatable {
    public let rows: [StationListRow]
    /// The ministry's timestamp of the oldest loaded province, for "Hace 12 min".
    public let pricesDate: Date?
    public let average: Decimal?
}

/// Gasolineras (Bear note 07, section 5): nearby stations for the chosen fuel, sorted and
/// filtered, with first load, updating, offline and empty states.
@MainActor @Observable
public final class StationListViewModel {
    public private(set) var product: Product = .diesel
    public var sort: StationSort = .cheapest {
        didSet { if sort != oldValue { observe() } }
    }
    public var levelFilter: LevelFilter = .all {
        didSet { if levelFilter != oldValue { observe() } }
    }
    /// Known as soon as the area is resolved, so the header shows during the first load.
    public private(set) var scope: ListScope?

    private var content: StationListContent?
    private var availableProducts: Set<Product> = []
    private var hasCache = false
    private var nearestOutside: Double?
    private var isRefreshing = false
    private var refreshFailure: DomainError?
    private var connectivity: Connectivity = .online
    private var offlineDismissed = false

    private var origin: Coordinate?
    private var area: NearbyArea?
    private var provinces: [ProvinceID] = []
    private var startCount = 0
    @ObservationIgnored private var observation: Task<Void, Never>?

    private let toggleFavoriteUseCase: ToggleFavorite
    private let observeNearby: ObserveNearbyStations
    private let refreshPrices: RefreshPrices
    private let resolveArea: ResolveArea
    private let observeConnectivity: ObserveConnectivity
    private let observeSettings: ObserveSettings
    private let updateSettings: UpdateSettings
    private let locateUser: LocateUser
    private let rememberArea: RememberArea?
    private let format: DisplayFormat
    private let now: @Sendable () -> Date

    public init(observeNearby: ObserveNearbyStations, refreshPrices: RefreshPrices,
                resolveArea: ResolveArea, observeConnectivity: ObserveConnectivity,
                observeSettings: ObserveSettings, updateSettings: UpdateSettings, locateUser: LocateUser,
                toggleFavorite: ToggleFavorite, rememberArea: RememberArea? = nil,
                format: DisplayFormat = DisplayFormat(), now: @escaping @Sendable () -> Date = { .now }) {
        self.toggleFavoriteUseCase = toggleFavorite
        self.observeNearby = observeNearby
        self.refreshPrices = refreshPrices
        self.resolveArea = resolveArea
        self.observeConnectivity = observeConnectivity
        self.observeSettings = observeSettings
        self.updateSettings = updateSettings
        self.locateUser = locateUser
        self.rememberArea = rememberArea
        self.format = format
        self.now = now
    }

    // MARK: State

    /// The fuels the menu offers: those with a station nearby.
    public var offeredProducts: [Product] { Product.offered(from: availableProducts, chosen: product) }

    public var state: ScreenState<StationListContent> {
        guard hasCache else {
            if isRefreshing || (refreshFailure == nil && connectivity == .online) { return .firstLoad }
            return .failed(connectivity == .offline ? .offline : refreshFailure ?? .serverUnavailable)
        }
        guard let content, !content.rows.isEmpty else {
            if let level = levelFilter.level { return .empty(.noStationsAtLevel(level)) }
            return .empty(.noStationsNearby(product, nearest: nearestOutside))
        }
        if connectivity == .offline {
            return .offline(content, age: content.pricesDate.map { now().timeIntervalSince($0) })
        }
        return isRefreshing ? .updating(content) : .content(content)
    }

    /// The red pill: offline and not dismissed since the connection dropped.
    public var isOfflinePillVisible: Bool { connectivity == .offline && !offlineDismissed }

    /// Time of the prices on screen, for "Hace 12 min" and "precios de hace 2 h".
    public var pricesDate: Date? { content?.pricesDate }

    // MARK: Intents

    /// Runs for as long as the screen is visible (call it from `.task`).
    public func start() async {
        // Swapping layouts can start a new screen before the old one's task ends; only the latest
        // run may stop the shared observation.
        startCount += 1
        let run = startCount
        let settings = await observeSettings.current()
        product = settings.product
        await findArea(settings: settings)
        observe()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refresh() }
            group.addTask { await self.watchConnectivity() }
            group.addTask { await self.watchSettings() }
            group.addTask { await self.watchLocation() }
        }
        guard run == startCount else { return }
        observation?.cancel()
    }

    /// Pull to refresh fetches even if the prices are under 30 minutes old.
    public func refresh(force: Bool = false) async {
        guard !provinces.isEmpty else { return }
        isRefreshing = true
        let outcome = await refreshPrices(provinces, force: force)
        isRefreshing = false
        refreshFailure = outcome.updated.isEmpty && outcome.skipped.isEmpty ? outcome.failed.values.first : nil
        await reload()
    }

    public func select(_ product: Product) async {
        guard product != self.product else { return }
        self.product = product
        observe()
        await updateSettings { $0.product = product }
    }

    /// The row's VoiceOver action "Añadir a favoritos" / "Quitar de favoritos". The nearby
    /// stream re-emits with the star once the favourites change.
    public func toggleFavorite(_ summary: StationSummary) async {
        _ = try? await toggleFavoriteUseCase(summary.station.id, province: summary.station.provinceID)
    }

    public func dismissOfflinePill() {
        offlineDismissed = true
    }

    // MARK: Loading

    private func findArea(settings: Settings) async {
        if await locateUser.status() == .authorized, let fix = await locateUser.firstFix() {
            await use(location: fix)
            return
        }
        let id = ResolveArea.province(for: settings)
        let resolved = await resolveArea(province: id)
        origin = nil
        provinces = resolved?.provinces ?? [id]
        area = resolved?.area
        scope = resolved?.provinceName.map { .province(name: $0) }
    }

    private func use(location: Coordinate) async {
        await rememberArea?(location)
        let resolved = await resolveArea(around: location)
        origin = resolved.origin
        area = resolved.area
        scope = .nearby(radius: ResolveArea.radius)
        provinces = resolved.provinces
    }

    private var request: NearbyRequest? {
        guard let area else { return nil }
        return NearbyRequest(provinces: provinces, area: area, product: product, sort: sort,
                             levels: levelFilter.levels, origin: origin)
    }

    /// Restarts the cache observation for the current fuel, sort, filter and area.
    private func observe() {
        observation?.cancel()
        guard let request else { return }
        observation = Task { [observeNearby] in
            for await result in observeNearby(request) {
                guard !Task.isCancelled else { return }
                await apply(result, for: request)
            }
        }
    }

    /// One-off read after a refresh, so a save that lands before the stream subscribes isn't missed.
    private func reload() async {
        guard let request, let result = try? await observeNearby.load(request) else { return }
        await apply(result, for: request)
    }

    private func apply(_ result: NearbyResult, for request: NearbyRequest) async {
        guard request == self.request else { return }
        hasCache = result.freshness != nil
        availableProducts = result.availableProducts
        let moment = now()
        content = StationListContent(
            rows: result.stations.map { summary in
                StationListRow(summary: summary, hours: HoursText.summary(
                    for: summary.station.hours, status: summary.openingStatus, at: moment, format: format))
            },
            pricesDate: result.freshness?.snapshotDate,
            average: result.summary?.average
        )
        nearestOutside = result.stations.isEmpty ? await nearestStation(for: request) : nil
    }

    /// "La más cercana está a 7,4 km": the closest station with the fuel, beyond the radius.
    private func nearestStation(for request: NearbyRequest) async -> Double? {
        guard let origin = request.origin else { return nil }
        var wider = request
        wider.area = .radius(center: origin, meters: 300_000)
        wider.levels = []
        wider.sort = .nearest
        return try? await observeNearby.load(wider).stations.first?.distance
    }

    // MARK: Device and settings

    private func watchConnectivity() async {
        for await update in await observeConnectivity() {
            let wasOffline = connectivity == .offline
            connectivity = update
            if update == .online, wasOffline {
                offlineDismissed = false
                await refresh()
            }
        }
    }

    private func watchSettings() async {
        for await settings in await observeSettings() where settings.product != product {
            product = settings.product
            observe()
        }
    }

    /// Moving more than a kilometre re-centres the list and loads any new provinces. A first fix
    /// that arrives late replaces the default province.
    private func watchLocation() async {
        guard await locateUser.status() == .authorized else { return }
        for await coordinate in await locateUser.updates() {
            if let origin, coordinate.distance(to: origin) <= 1000 { continue }
            await use(location: coordinate)
            observe()
            await refresh()
        }
    }
}
