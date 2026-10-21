import DomainLayer
import Foundation
import Observation

/// "La más barata cerca": the cheapest station within 3 km of the user (or of the map centre).
public struct CheapestNearby: Sendable, Equatable {
    public let summary: StationSummary
    public let hours: HoursSummary
    /// Average minus price: positive means below the average ("0,065 € bajo la media").
    public let belowAverage: Decimal?
    public let radius: Double
}

public struct MapContent: Sendable, Equatable {
    public let pins: [StationPin]
    public let cheapest: CheapestNearby?
    public let average: Decimal?
    public let pricesDate: Date?
}

/// A camera move the view should perform: the first position, a cluster tap, "Centrar en mi ubicación".
public struct CameraMove: Sendable, Equatable {
    public let id: Int
    public let viewport: MapViewport
}

/// Mapa (Bear note 07, section 5): price pins for the stations in view, loading the provinces the
/// viewport touches, with overlap-only clustering and the cheapest-nearby card.
@MainActor @Observable
public final class MapViewModel {
    public static let nearbyRadius: Double = 3000
    /// Wider than this and the map would need too many provinces; it asks the user to zoom in.
    public static let maximumSpan: Double = 1.6
    /// About 3 km around the user when the map opens.
    public static let initialSpan: Double = 0.06

    public private(set) var product: Product = .diesel
    public var levelFilter: LevelFilter = .all {
        didSet { if levelFilter != oldValue { observe() } }
    }
    /// Part of the request (for distances), so any change restarts the observation.
    public private(set) var userLocation: Coordinate? {
        didSet { if userLocation != oldValue { observe() } }
    }
    public private(set) var cameraMove: CameraMove?
    /// The last settled viewport. Kept here so the map reopens where it was after a layout change.
    public private(set) var viewport: MapViewport?
    /// Grey "---" pins from the bundled station samples, shown until prices arrive.
    public private(set) var placeholderPins: [StationPin] = []

    private var result: NearbyResult?
    private var content: MapContent?
    private var isRefreshing = false
    private var refreshFailure: DomainError?
    private var connectivity: Connectivity = .online
    private var offlineDismissed = false
    private var provinces: [ProvinceID] = []
    private var mapWidth: Double = 390
    private var moveCount = 0
    /// MapKit reports a camera of its own before `start()` runs, so "has a viewport" isn't enough.
    private var hasPlacedCamera = false
    private var startCount = 0
    @ObservationIgnored private var observation: Task<Void, Never>?
    @ObservationIgnored private var settling: Task<Void, Never>?

    private let observeNearby: ObserveNearbyStations
    private let refreshPrices: RefreshPrices
    private let resolveProvinces: ResolveProvinces
    private let observeConnectivity: ObserveConnectivity
    private let observeSettings: ObserveSettings
    private let updateSettings: UpdateSettings
    private let locateUser: LocateUser
    private let clusterer = PinClusterer()
    private let format: DisplayFormat
    private let settleDelay: Duration
    private let now: @Sendable () -> Date

    public init(observeNearby: ObserveNearbyStations, refreshPrices: RefreshPrices,
                resolveProvinces: ResolveProvinces, observeConnectivity: ObserveConnectivity,
                observeSettings: ObserveSettings, updateSettings: UpdateSettings, locateUser: LocateUser,
                format: DisplayFormat = DisplayFormat(), settleDelay: Duration = .milliseconds(500),
                now: @escaping @Sendable () -> Date = { .now }) {
        self.observeNearby = observeNearby
        self.refreshPrices = refreshPrices
        self.resolveProvinces = resolveProvinces
        self.observeConnectivity = observeConnectivity
        self.observeSettings = observeSettings
        self.updateSettings = updateSettings
        self.locateUser = locateUser
        self.format = format
        self.settleDelay = settleDelay
        self.now = now
    }

    // MARK: State

    public var isZoomedOut: Bool { (viewport?.latitudeDelta ?? 0) > Self.maximumSpan }

    public var state: ScreenState<MapContent> {
        guard result?.freshness != nil, let content else {
            if isRefreshing || (refreshFailure == nil && connectivity == .online) { return .firstLoad }
            return .failed(connectivity == .offline ? .offline : refreshFailure ?? .serverUnavailable)
        }
        if connectivity == .offline {
            return .offline(content, age: content.pricesDate.map { now().timeIntervalSince($0) })
        }
        return isRefreshing ? .updating(content) : .content(content)
    }

    public var isOfflinePillVisible: Bool { connectivity == .offline && !offlineDismissed }

    // MARK: Intents

    /// Runs for as long as the map is on screen (call it from `.task`).
    public func start() async {
        // Swapping layouts can start a new screen before the old one's task ends; only the latest
        // run may tear down what the screens share.
        startCount += 1
        let run = startCount
        let settings = await observeSettings.current()
        product = settings.product
        if !hasPlacedCamera {
            hasPlacedCamera = true
            await placeInitialCamera(settings: settings)
        } else if let viewport {
            // Back from another layout: resume where the map was.
            move(to: viewport)
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.watchConnectivity() }
            group.addTask { await self.watchSettings() }
            group.addTask { await self.watchLocation() }
        }
        guard run == startCount else { return }
        observation?.cancel()
        settling?.cancel()
    }

    /// The camera stopped moving. Loads after a short pause so a pan doesn't fire a request per frame.
    public func viewportChanged(_ viewport: MapViewport, width: Double) {
        self.viewport = viewport
        mapWidth = width
        settling?.cancel()
        settling = Task { [settleDelay] in
            try? await Task.sleep(for: settleDelay)
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    public func select(_ product: Product) async {
        guard product != self.product else { return }
        self.product = product
        observe()
        await updateSettings { $0.product = product }
    }

    /// Tapping a group zooms until its pins separate.
    public func zoom(into bounds: BoundingBox) {
        let span = max(bounds.maxLatitude - bounds.minLatitude, bounds.maxLongitude - bounds.minLongitude) * 1.6
        move(to: MapViewport(center: bounds.center, latitudeDelta: max(span, 0.004), longitudeDelta: max(span, 0.004)))
    }

    public func centerOnUser() async {
        if userLocation == nil, await locateUser.authorize() == .authorized {
            userLocation = await locateUser.firstFix()
        }
        guard let userLocation else { return }
        move(to: MapViewport(center: userLocation, latitudeDelta: Self.initialSpan, longitudeDelta: Self.initialSpan))
    }

    public func refresh(force: Bool = false) async {
        guard !provinces.isEmpty else { return }
        isRefreshing = true
        let outcome = await refreshPrices(provinces, force: force)
        isRefreshing = false
        refreshFailure = outcome.updated.isEmpty && outcome.skipped.isEmpty ? outcome.failed.values.first : nil
        await reload()
    }

    public func dismissOfflinePill() {
        offlineDismissed = true
    }

    // MARK: Loading

    private func placeInitialCamera(settings: Settings) async {
        if await locateUser.authorize() == .authorized, let fix = await locateUser.firstFix() {
            userLocation = fix
            move(to: MapViewport(center: fix, latitudeDelta: Self.initialSpan, longitudeDelta: Self.initialSpan))
            return
        }
        let id = settings.defaultProvinceID ?? settings.lastViewedProvinceID ?? StationListViewModel.fallbackProvince
        guard let province = await resolveProvinces.province(id) else { return }
        // The province's main area rather than its whole outline, so prices are readable at once.
        move(to: MapViewport(center: province.bounds.center, latitudeDelta: 0.3, longitudeDelta: 0.3))
    }

    private func move(to viewport: MapViewport) {
        moveCount += 1
        cameraMove = CameraMove(id: moveCount, viewport: viewport)
    }

    private func load() async {
        guard let viewport, !isZoomedOut else {
            observation?.cancel()
            return
        }
        provinces = await resolveProvinces(viewport: viewport)
        await updatePlaceholders(in: viewport)
        observe()
        await refresh()
    }

    private func updatePlaceholders(in viewport: MapViewport) async {
        var samples: [Coordinate] = []
        for id in provinces {
            guard let province = await resolveProvinces.province(id) else { continue }
            samples += province.samples.filter { viewport.bounds.contains($0) }
        }
        placeholderPins = samples.prefix(40).enumerated().map { StationPin.placeholder(id: $0, $1) }
    }

    private var request: NearbyRequest? {
        guard let viewport, !provinces.isEmpty else { return nil }
        return NearbyRequest(provinces: provinces, area: .bounds(viewport.bounds), product: product,
                             sort: .cheapest, levels: levelFilter.levels, origin: userLocation)
    }

    private func observe() {
        observation?.cancel()
        guard let request else { return }
        observation = Task { [observeNearby] in
            for await result in observeNearby(request) {
                guard !Task.isCancelled else { return }
                apply(result, for: request)
            }
        }
    }

    private func reload() async {
        guard let request, let result = try? await observeNearby.load(request) else { return }
        apply(result, for: request)
    }

    private func apply(_ result: NearbyResult, for request: NearbyRequest) {
        guard request == self.request, let viewport else { return }
        self.result = result
        let cheapest = cheapest(in: result, viewport: viewport)
        content = MapContent(
            pins: clusterer.pins(for: result.stations, in: viewport, width: mapWidth, standalone: cheapest?.summary.id),
            cheapest: cheapest,
            average: result.summary?.average,
            pricesDate: result.freshness?.snapshotDate
        )
    }

    /// Around the user when they're in view, otherwise around the map centre.
    private func cheapest(in result: NearbyResult, viewport: MapViewport) -> CheapestNearby? {
        let center = userLocation.flatMap { viewport.bounds.contains($0) ? $0 : nil } ?? viewport.center
        guard let best = result.stations
            .filter({ $0.station.coordinate.distance(to: center) <= Self.nearbyRadius })
            .min(by: { $0.price.amount < $1.price.amount }) else { return nil }
        return CheapestNearby(
            summary: best,
            hours: HoursText.summary(for: best.station.hours, status: best.openingStatus, at: now(), format: format),
            belowAverage: result.summary.map { $0.average - best.price.amount },
            radius: Self.nearbyRadius
        )
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

    private func watchLocation() async {
        guard await locateUser.authorize() == .authorized else { return }
        for await coordinate in await locateUser.updates() {
            guard let current = userLocation else {
                // The first fix came after the map had fallen back to the default province.
                userLocation = coordinate
                move(to: MapViewport(center: coordinate, latitudeDelta: Self.initialSpan, longitudeDelta: Self.initialSpan))
                continue
            }
            // Distances only need refreshing once the user has moved a little.
            guard coordinate.distance(to: current) > 200 else { continue }
            userLocation = coordinate
        }
    }
}
