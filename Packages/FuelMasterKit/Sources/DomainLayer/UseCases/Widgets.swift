import Foundation

/// The area the widgets and background refresh work with: where the app last saw the user, or
/// else the default (or last viewed) province.
public struct LastArea: Sendable, Equatable {
    public let provinces: [ProvinceID]
    public let area: NearbyArea
    /// The last known position, for distances. Nil when only a province is known.
    public let origin: Coordinate?
}

/// Resolves `LastArea` from the settings. Shared by `GetWidgetSnapshot` and `RefreshInBackground`.
struct ResolveLastArea: Sendable {
    /// The list's radius, so the widget's "cheapest nearby" matches the first row of Gasolineras.
    static let radius: Double = 3000
    /// Used when there's no location and no province set yet.
    static let fallbackProvince = ProvinceID("28")

    let provinces: any ProvinceRepository

    func callAsFunction(_ settings: Settings) async -> LastArea? {
        let resolve = ResolveProvinces(provinces: provinces)
        if let location = settings.lastLocation {
            return LastArea(provinces: await resolve(around: location),
                            area: .radius(center: location, meters: Self.radius), origin: location)
        }
        let id = settings.defaultProvinceID ?? settings.lastViewedProvinceID ?? Self.fallbackProvince
        guard let province = await resolve.province(id) else { return nil }
        return LastArea(provinces: [id], area: .bounds(province.bounds), origin: nil)
    }
}

/// Remembers where the app last saw the user, so the widgets and background refresh know which
/// area to show and update. Small moves aren't written, to keep settings quiet.
public struct RememberArea: Sendable {
    /// Moves shorter than this keep the stored position.
    public static let minimumMove: Double = 500

    private let settings: any SettingsRepository
    private let provinces: any ProvinceRepository

    public init(settings: any SettingsRepository, provinces: any ProvinceRepository) {
        self.settings = settings
        self.provinces = provinces
    }

    public func callAsFunction(_ location: Coordinate) async {
        if let stored = await settings.current().lastLocation, stored.distance(to: location) < Self.minimumMove { return }
        let province = await provinces.province(at: location)
        // Read again right before writing, so a change made meanwhile (a new fuel) isn't undone.
        var current = await settings.current()
        current.lastLocation = location
        if let province { current.lastViewedProvinceID = province }
        await settings.update(current)
    }
}

/// What every widget shows, read from the cache only (Bear note 06, "Background and widgets").
public struct WidgetSnapshot: Sendable, Equatable {
    public let product: Product
    public let priceScale: PriceScale
    public let accent: AccentChoice
    /// The cheapest station near the last known position, or in the province.
    public let cheapest: StationSummary?
    /// Average, minimum and maximum of the area, for the gap to the average and the gauge.
    public let summary: AreaPriceSummary?
    /// Favourites that have a price for the product, in the user's order, with yesterday's change.
    public let favorites: [FavoriteSummary]
    /// The oldest province shown; nil when nothing is cached yet.
    public let freshness: Freshness?
    public let favoritesFreshness: Freshness?

    public init(product: Product, priceScale: PriceScale, accent: AccentChoice = .preset(.orange),
                cheapest: StationSummary?, summary: AreaPriceSummary?,
                favorites: [FavoriteSummary], freshness: Freshness?, favoritesFreshness: Freshness?) {
        self.product = product
        self.priceScale = priceScale
        self.accent = accent
        self.cheapest = cheapest
        self.summary = summary
        self.favorites = favorites
        self.freshness = freshness
        self.favoritesFreshness = favoritesFreshness
    }
}

/// Builds the widgets' snapshot from the cache and settings. No network: the app and the
/// background refresh keep the cache up to date.
public struct GetWidgetSnapshot: Sendable {
    /// When nothing sells the fuel within the radius, the nearest station within this distance.
    static let widerRadius: Double = 25_000

    private let settings: any SettingsRepository
    private let lastArea: ResolveLastArea
    private let nearby: ObserveNearbyStations
    private let observeFavorites: ObserveFavorites

    public init(settings: any SettingsRepository, provinces: any ProvinceRepository,
                nearby: ObserveNearbyStations, favorites: ObserveFavorites) {
        self.settings = settings
        lastArea = ResolveLastArea(provinces: provinces)
        self.nearby = nearby
        observeFavorites = favorites
    }

    public func callAsFunction() async -> WidgetSnapshot {
        let settings = await settings.current()
        var cheapest: StationSummary?
        var summary: AreaPriceSummary?
        var freshness: Freshness?
        if let area = await lastArea(settings) {
            var request = NearbyRequest(provinces: area.provinces, area: area.area, product: settings.product,
                                        sort: .cheapest, origin: area.origin)
            if let result = try? await nearby.load(request) {
                cheapest = result.stations.first
                summary = result.summary
                freshness = result.freshness
                if cheapest == nil, let origin = area.origin {
                    request.area = .radius(center: origin, meters: Self.widerRadius)
                    request.sort = .nearest
                    cheapest = try? await nearby.load(request).stations.first
                }
            }
        }
        let favorites = try? await observeFavorites.load(
            FavoritesRequest(product: settings.product, tankSize: settings.tankSize, origin: settings.lastLocation))
        return WidgetSnapshot(
            product: settings.product, priceScale: settings.priceScale, accent: settings.accent, cheapest: cheapest, summary: summary,
            favorites: favorites?.items.filter { $0.summary != nil } ?? [], freshness: freshness,
            favoritesFreshness: favorites?.freshness
        )
    }
}

/// The hourly background refresh: the last area plus the favourites' provinces, each fetched only
/// if its prices are over 30 minutes old. `RefreshPrices` reloads the widgets when anything changed.
public struct RefreshInBackground: Sendable {
    private let settings: any SettingsRepository
    private let lastArea: ResolveLastArea
    private let favorites: any FavoriteStationsRepository
    private let refreshPrices: RefreshPrices

    public init(settings: any SettingsRepository, provinces: any ProvinceRepository,
                favorites: any FavoriteStationsRepository, refreshPrices: RefreshPrices) {
        self.settings = settings
        lastArea = ResolveLastArea(provinces: provinces)
        self.favorites = favorites
        self.refreshPrices = refreshPrices
    }

    /// The provinces a run would refresh, in order.
    public func provinces() async -> [ProvinceID] {
        var result = Set(await lastArea(await settings.current())?.provinces ?? [])
        for entry in (try? await favorites.favorites()) ?? [] { result.insert(entry.provinceID) }
        return result.sorted()
    }

    @discardableResult
    public func callAsFunction() async -> RefreshOutcome {
        await refreshPrices(await provinces())
    }
}
