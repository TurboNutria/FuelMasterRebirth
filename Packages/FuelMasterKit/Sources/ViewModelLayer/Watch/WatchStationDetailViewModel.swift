import DomainLayer
import Foundation
import Observation

public struct WatchStationDetailContent: Sendable, Equatable {
    public let detail: StationDetail
    public let hours: HoursSummary
    public let isFavorite: Bool
    /// The chosen fuel, which the station may not sell.
    public let product: Product

    public var station: Station { detail.station }
}

/// The watch's station detail (canvas: Watch · Detalle; Bear note 06, "Apple Watch"): price,
/// gap to the average, hours, distance and favourite. No history or tank cost, so opening it
/// never downloads anything.
@MainActor @Observable
public final class WatchStationDetailViewModel {
    public private(set) var stationID: StationID?
    public private(set) var product: Product = .diesel

    private var detail: StationDetail?
    private var detailProduct: Product = .diesel
    private var resolved = false
    /// The tapped value, until the favourites stream confirms it.
    private var favoriteOverride: Bool?
    private var origin: Coordinate?
    @ObservationIgnored private var observation: Task<Void, Never>?

    private let getDetail: GetStationDetail
    private let toggleFavoriteUseCase: ToggleFavorite
    private let observeSettings: ObserveSettings
    private let locateUser: LocateUser
    private let format: DisplayFormat
    private let now: @Sendable () -> Date

    public init(getDetail: GetStationDetail, toggleFavorite: ToggleFavorite, observeSettings: ObserveSettings,
                locateUser: LocateUser, format: DisplayFormat = DisplayFormat(),
                now: @escaping @Sendable () -> Date = { .now }) {
        self.getDetail = getDetail
        self.toggleFavoriteUseCase = toggleFavorite
        self.observeSettings = observeSettings
        self.locateUser = locateUser
        self.format = format
        self.now = now
    }

    public var state: ScreenState<WatchStationDetailContent> {
        guard resolved else { return .firstLoad }
        guard let detail else { return .failed(.notFound) }
        let hours = HoursText.summary(for: detail.station.hours, status: detail.openingStatus, at: now(), format: format)
        return .content(WatchStationDetailContent(detail: detail, hours: hours,
                                                  isFavorite: favoriteOverride ?? detail.isFavorite,
                                                  product: detailProduct))
    }

    /// Runs while the detail is on screen (call it from `.task(id:)`).
    public func show(_ id: StationID) async {
        if id != stationID {
            stationID = id
            detail = nil
            resolved = false
            favoriteOverride = nil
        }
        product = await observeSettings.current().product
        if await locateUser.status() == .authorized { origin = await locateUser.firstFix() }
        observe()
        await watchSettings()
        observation?.cancel()
    }

    public func toggleFavorite() async {
        guard let detail else { return }
        favoriteOverride = !(favoriteOverride ?? detail.isFavorite)
        do {
            favoriteOverride = try await toggleFavoriteUseCase(detail.station.id, province: detail.station.provinceID)
        } catch {
            favoriteOverride = nil
        }
    }

    private var request: StationDetailRequest? {
        // No tank cost on the watch, so the tank size doesn't matter.
        stationID.map { StationDetailRequest(stationID: $0, product: product, tankSize: Settings.default.tankSize,
                                             origin: origin) }
    }

    private func observe() {
        observation?.cancel()
        guard let request else { return }
        observation = Task { [getDetail] in
            for await next in getDetail(request) {
                guard !Task.isCancelled, request == self.request else { return }
                detail = next
                detailProduct = request.product
                resolved = true
                if let next, favoriteOverride == next.isFavorite { favoriteOverride = nil }
            }
        }
    }

    private func watchSettings() async {
        for await settings in await observeSettings() where settings.product != product {
            product = settings.product
            observe()
        }
    }
}

/// "Hace 3 h" when prices are over an hour old, as on the widgets (Bear note 06); nil while fresh.
public enum StaleAge {
    public static func text(pricesDate: Date?, now: Date, format: DisplayFormat = DisplayFormat()) -> String? {
        guard let pricesDate, now.timeIntervalSince(pricesDate) > WidgetContent.staleAfter else { return nil }
        return format.relativeTime(pricesDate, now: now)
    }
}
