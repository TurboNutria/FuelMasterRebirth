import DomainLayer
import Foundation
import Observation

public struct MapContent: Sendable, Equatable {
    public let pins: [StationPin]
    public let average: Decimal?
    public let pricesDate: Date?
}

/// A camera move the view should perform: the first position, a cluster tap, "Centrar en mi ubicación".
public struct CameraMove: Sendable, Equatable {
    public let id: Int
    public let viewport: MapViewport
    /// The zoom of an earlier camera, when the move restores one: its height in metres per point
    /// of map height. A map of another shape (after rotating) keeps the zoom rather than the camera
    /// height, which zoomed out about 2× in landscape. A viewport alone is re-fitted to the map's
    /// shape, which zooms out a little on every layout change.
    public let zoom: Double?
}

/// Mapa (Bear note 07, section 5): price pins for the stations in view, loading the provinces the
/// viewport touches, with overlap-only clustering.
@MainActor @Observable
public final class MapViewModel {
    /// Wider than this and the map would need too many provinces; it asks the user to zoom in.
    public static let maximumSpan: Double = 1.6
    /// About 3 km around the user when the map opens.
    public static let initialSpan: Double = 0.06
    /// About 1 km around a station shown from a list.
    public static let focusSpan: Double = 0.01
    /// Stations are loaded for an area this many times the visible one, and never smaller than
    /// `minimumLoadedSpan` (about 11 km), so panning and zooming in show pins that are already
    /// there instead of loading a handful at a time (QA 2026-11-11).
    static let loadedAreaFactor: Double = 2
    static let minimumLoadedSpan: Double = 0.1
    /// Pins are drawn this far around the visible area: a screen in every direction.
    static let drawnAreaFactor: Double = 3

    public private(set) var product: Product = .diesel
    public var levelFilter: LevelFilter = .all {
        didSet { if levelFilter != oldValue { observe() } }
    }
    /// Part of the request (for distances), so any change restarts the observation.
    public private(set) var userLocation: Coordinate? {
        didSet {
            guard userLocation != oldValue else { return }
            observe()
        }
    }
    public private(set) var cameraMove: CameraMove?
    /// MapKit's user annotation asks for location by itself, so the map only adds it once allowed.
    public private(set) var showsUserLocation = false
    /// The last settled viewport. Kept here so the map reopens where it was after a layout change.
    public private(set) var viewport: MapViewport?
    private var cameraZoom: Double?
    /// The last move a map has shown, so a map built later doesn't replay it.
    @ObservationIgnored private var shownMoveID: Int?
    /// Grey "---" pins from the bundled station samples, shown until prices arrive.
    public private(set) var placeholderPins: [StationPin] = []

    private var result: NearbyResult?
    private var content: MapContent?
    private var isRefreshing = false
    private var refreshFailure: DomainError?
    private var connectivity: Connectivity = .online
    private var offlineDismissed = false
    private var provinces: [ProvinceID] = []
    /// The area the current stations were loaded for.
    private var loadedArea: MapViewport?
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
    private let resolveArea: ResolveArea
    private let observeConnectivity: ObserveConnectivity
    private let observeSettings: ObserveSettings
    private let updateSettings: UpdateSettings
    private let locateUser: LocateUser
    private let rememberArea: RememberArea?
    private let clusterer = PinClusterer()
    private let settleDelay: Duration
    private let now: @Sendable () -> Date

    public init(observeNearby: ObserveNearbyStations, refreshPrices: RefreshPrices,
                resolveProvinces: ResolveProvinces, resolveArea: ResolveArea, observeConnectivity: ObserveConnectivity,
                observeSettings: ObserveSettings, updateSettings: UpdateSettings, locateUser: LocateUser,
                rememberArea: RememberArea? = nil, settleDelay: Duration = .milliseconds(200),
                now: @escaping @Sendable () -> Date = { .now }) {
        self.observeNearby = observeNearby
        self.refreshPrices = refreshPrices
        self.resolveProvinces = resolveProvinces
        self.resolveArea = resolveArea
        self.observeConnectivity = observeConnectivity
        self.observeSettings = observeSettings
        self.updateSettings = updateSettings
        self.locateUser = locateUser
        self.rememberArea = rememberArea
        self.settleDelay = settleDelay
        self.now = now
    }

    // MARK: State

    /// The fuels the menu offers: those with a station in view.
    public var offeredProducts: [Product] {
        Product.offered(from: result?.availableProducts ?? [], chosen: product)
    }

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

    /// Where a newly built map opens: a move no map has shown yet (such as "Ver en el mapa" from
    /// the list), otherwise the last settled camera. Rotating swaps layouts and builds a new map;
    /// replaying the last move there jumped back to the user's location.
    public var openingCamera: CameraMove? {
        guard let cameraMove, cameraMove.id == shownMoveID, let viewport else { return cameraMove }
        return CameraMove(id: cameraMove.id, viewport: viewport, zoom: cameraZoom)
    }

    // MARK: Intents

    /// Runs for as long as the map is on screen (call it from `.task`).
    public func start() async {
        // Swapping layouts can start a new screen before the old one's task ends; only the latest
        // run may tear down what the screens share.
        startCount += 1
        let run = startCount
        let settings = await observeSettings.current()
        product = settings.product
        showsUserLocation = await locateUser.status() == .authorized
        // Back from another layout, the new map already opened where the old one was (`openingCamera`).
        if !hasPlacedCamera {
            hasPlacedCamera = true
            await placeInitialCamera(settings: settings)
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

    /// The camera stopped moving. Regroups the loaded pins for the new zoom at once, and loads
    /// only when the map has left the loaded area, after a short pause so a pan doesn't fire a
    /// request per frame.
    public func viewportChanged(_ viewport: MapViewport, width: Double, zoom: Double? = nil) {
        self.viewport = viewport
        cameraZoom = zoom
        mapWidth = width
        settling?.cancel()
        if !isZoomedOut, let loadedArea, Self.covers(loadedArea, viewport) {
            redrawPins()
            return
        }
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

    /// "Ver en el mapa": close enough around the station for its pin to stand on its own.
    public func focus(on coordinate: Coordinate) {
        // Before the map's first `start()` this is the first position, not the user's area.
        hasPlacedCamera = true
        move(to: MapViewport(center: coordinate, latitudeDelta: Self.focusSpan, longitudeDelta: Self.focusSpan))
    }

    public func centerOnUser() async {
        if userLocation == nil, await locateUser.authorize() == .authorized {
            showsUserLocation = true
            userLocation = await locateUser.firstFix()
            await remember(userLocation)
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

    /// A map moved its camera for `move`.
    public func cameraMoveShown(_ move: CameraMove) {
        shownMoveID = move.id
    }

    public func dismissOfflinePill() {
        offlineDismissed = true
    }

    // MARK: Loading

    private func placeInitialCamera(settings: Settings) async {
        if await locateUser.status() == .authorized, let fix = await locateUser.firstFix() {
            userLocation = fix
            await remember(fix)
            move(to: MapViewport(center: fix, latitudeDelta: Self.initialSpan, longitudeDelta: Self.initialSpan))
            return
        }
        guard case .bounds(let bounds)? = await resolveArea(province: ResolveArea.province(for: settings))?.area else { return }
        // The province's main area rather than its whole outline, so prices are readable at once.
        move(to: MapViewport(center: bounds.center, latitudeDelta: 0.3, longitudeDelta: 0.3))
    }

    private func move(to viewport: MapViewport) {
        moveCount += 1
        cameraMove = CameraMove(id: moveCount, viewport: viewport, zoom: nil)
    }

    private func load() async {
        guard let viewport, !isZoomedOut else {
            observation?.cancel()
            return
        }
        let area = Self.loadedArea(for: viewport)
        provinces = await resolveProvinces(viewport: area)
        loadedArea = area
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
        guard let loadedArea, !provinces.isEmpty else { return nil }
        return NearbyRequest(provinces: provinces, area: .bounds(loadedArea.bounds), product: product,
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
        guard request == self.request else { return }
        self.result = result
        redrawPins()
    }

    /// Groups the loaded stations for the current zoom. Only those within a screen of the visible
    /// area become pins, so a street-level view doesn't carry a whole city's worth.
    private func redrawPins() {
        guard let result, let viewport else { return }
        let drawn = MapViewport(center: viewport.center,
                                latitudeDelta: viewport.latitudeDelta * Self.drawnAreaFactor,
                                longitudeDelta: viewport.longitudeDelta * Self.drawnAreaFactor).bounds
        let stations = result.stations.filter { drawn.contains($0.station.coordinate) }
        content = MapContent(
            pins: clusterer.pins(for: stations, in: viewport, width: mapWidth),
            average: result.summary?.average,
            pricesDate: result.freshness?.snapshotDate
        )
    }

    static func loadedArea(for viewport: MapViewport) -> MapViewport {
        MapViewport(center: viewport.center,
                    latitudeDelta: max(viewport.latitudeDelta * loadedAreaFactor, minimumLoadedSpan),
                    longitudeDelta: max(viewport.longitudeDelta * loadedAreaFactor, minimumLoadedSpan))
    }

    /// Whether `loaded` still serves `viewport`: the visible area is inside it, and it isn't so
    /// much larger than a fresh load would be (after zooming far in) that it's worth trimming.
    static func covers(_ loaded: MapViewport, _ viewport: MapViewport) -> Bool {
        let outer = loaded.bounds, inner = viewport.bounds
        let wanted = loadedArea(for: viewport)
        return outer.minLatitude <= inner.minLatitude && outer.maxLatitude >= inner.maxLatitude
            && outer.minLongitude <= inner.minLongitude && outer.maxLongitude >= inner.maxLongitude
            && loaded.latitudeDelta <= wanted.latitudeDelta * 4
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
        guard await locateUser.status() == .authorized else { return }
        for await coordinate in await locateUser.updates() {
            guard let current = userLocation else {
                // The first fix came after the map had fallen back to the default province.
                userLocation = coordinate
                move(to: MapViewport(center: coordinate, latitudeDelta: Self.initialSpan, longitudeDelta: Self.initialSpan))
                await remember(coordinate)
                continue
            }
            // Distances only need refreshing once the user has moved a little.
            guard coordinate.distance(to: current) > 200 else { continue }
            userLocation = coordinate
            await remember(coordinate)
        }
    }

    /// Records the position for the widgets and background refresh. Awaited in order, so an older
    /// position can't be written after a newer one.
    private func remember(_ location: Coordinate?) async {
        guard let location, let rememberArea else { return }
        await rememberArea(location)
    }
}
