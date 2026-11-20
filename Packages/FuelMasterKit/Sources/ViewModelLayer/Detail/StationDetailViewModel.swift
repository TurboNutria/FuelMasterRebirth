import DomainLayer
import Foundation
import Observation

public struct StationDetailContent: Sendable, Equatable {
    public let detail: StationDetail
    public let hours: HoursSummary
    public let chart: HistoryChart?
    public let isFavorite: Bool
    /// The chosen product, which the station may not sell.
    public let product: Product

    public var station: Station { detail.station }
}

private struct HistoryKey: Equatable {
    let stationID: StationID
    let product: Product
}

/// Station detail (Bear note 07, section 5): price against the area, full-tank cost, 7-day chart,
/// other fuels, favourite. One instance lives above the layouts, so the selection keeps its state
/// when the sheet becomes an inspector or a pushed screen.
@MainActor @Observable
public final class StationDetailViewModel {
    public private(set) var stationID: StationID?
    public private(set) var product: Product = .diesel

    private var detail: StationDetail?
    /// The product `detail` was loaded for; `product` can run ahead of it after a settings change.
    private var detailProduct: Product = .diesel
    /// True once the cache has answered for the current station, so "not found" can be told
    /// apart from "still loading".
    private var resolved = false
    private var history: PriceHistory?
    private var isLoadingHistory = false
    private var historyFailed = false
    /// The tapped value, until the favourites stream confirms it.
    private var favoriteOverride: Bool?
    private var tankSize: Decimal = Settings.default.tankSize
    private var origin: Coordinate?
    /// Screens currently showing the detail. Layout swaps overlap them, and the newer one can be
    /// the short-lived one (iPad launch: tabs push, then inspector), so only the last to leave
    /// tears down.
    private var activeRuns = 0
    /// Station and product the history was last requested for. History waits for the first
    /// detail, because on a cold cache the station only appears once its province has loaded.
    @ObservationIgnored private var historyKey: HistoryKey?
    @ObservationIgnored private var observation: Task<Void, Never>?
    @ObservationIgnored private var historyLoad: Task<Void, Never>?

    private let getDetail: GetStationDetail
    private let getHistory: GetPriceHistory
    private let toggleFavorite: ToggleFavorite
    private let observeSettings: ObserveSettings
    private let locateUser: LocateUser
    private let format: DisplayFormat
    private let now: @Sendable () -> Date

    public init(getDetail: GetStationDetail, getHistory: GetPriceHistory, toggleFavorite: ToggleFavorite,
                observeSettings: ObserveSettings, locateUser: LocateUser,
                format: DisplayFormat = DisplayFormat(), now: @escaping @Sendable () -> Date = { .now }) {
        self.getDetail = getDetail
        self.getHistory = getHistory
        self.toggleFavorite = toggleFavorite
        self.observeSettings = observeSettings
        self.locateUser = locateUser
        self.format = format
        self.now = now
    }

    // MARK: State

    public var state: ScreenState<StationDetailContent> {
        guard resolved else { return .firstLoad }
        guard let detail else { return .failed(.notFound) }
        let hours = HoursText.summary(for: detail.station.hours, status: detail.openingStatus, at: now(), format: format)
        return .content(StationDetailContent(detail: detail, hours: hours, chart: chart,
                                             isFavorite: favoriteOverride ?? detail.isFavorite, product: detailProduct))
    }

    private var chart: HistoryChart? {
        history.flatMap { HistoryChart(history: $0, isLoading: isLoadingHistory, isIncomplete: historyFailed) }
    }

    /// Apple Maps link for Compartir.
    public var shareURL: URL? { detail?.station.shareURL }

    // MARK: Intents

    /// Runs while the detail is on screen (call it from `.task(id:)` with the selected station).
    public func show(_ id: StationID) async {
        activeRuns += 1
        if id != stationID {
            stationID = id
            detail = nil
            resolved = false
            history = nil
            historyKey = nil
            historyFailed = false
            favoriteOverride = nil
        }
        let settings = await observeSettings.current()
        product = settings.product
        tankSize = settings.tankSize
        observe()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.watchSettings() }
            group.addTask { await self.watchLocation() }
        }
        activeRuns -= 1
        guard activeRuns == 0 else { return }
        observation?.cancel()
        historyLoad?.cancel()
        // Reopening the same station tries its history again.
        historyKey = nil
    }

    public func toggleFavorite() async {
        guard let detail else { return }
        let wanted = !(favoriteOverride ?? detail.isFavorite)
        favoriteOverride = wanted
        do {
            favoriteOverride = try await toggleFavorite(detail.station.id, province: detail.station.provinceID)
        } catch {
            favoriteOverride = nil
        }
    }

    /// Tries the missing history days again.
    public func retryHistory() async {
        await loadHistory()
    }

    // MARK: Loading

    private var request: StationDetailRequest? {
        stationID.map { StationDetailRequest(stationID: $0, product: product, tankSize: tankSize, origin: origin) }
    }

    private func observe() {
        observation?.cancel()
        guard let request else { return }
        observation = Task { [getDetail, getHistory] in
            for await next in getDetail(request) {
                guard !Task.isCancelled, request == self.request else { return }
                apply(next, product: request.product)
                guard next != nil else { continue }
                let key = HistoryKey(stationID: request.stationID, product: request.product)
                if historyKey != key {
                    historyKey = key
                    historyLoad?.cancel()
                    historyLoad = Task { await loadHistory() }
                } else if let refreshed = try? await getHistory.cached(station: request.stationID, product: request.product),
                          request == self.request {
                    // New current prices move today's point.
                    history = refreshed
                }
            }
        }
    }

    private func apply(_ next: StationDetail?, product: Product) {
        detail = next
        detailProduct = product
        resolved = true
        if let next, favoriteOverride == next.isFavorite { favoriteOverride = nil }
    }

    private func loadHistory() async {
        guard let id = stationID else { return }
        let product = self.product
        if let cached = try? await getHistory.cached(station: id, product: product) { history = cached }
        isLoadingHistory = true
        historyFailed = false
        do {
            let fetched = try await getHistory(station: id, product: product)
            if let fetched, id == stationID, product == self.product { history = fetched }
        } catch {
            if id == stationID, !Task.isCancelled { historyFailed = true }
        }
        isLoadingHistory = false
    }

    private func watchSettings() async {
        for await settings in await observeSettings() {
            guard settings.product != product || settings.tankSize != tankSize else { continue }
            let productChanged = settings.product != product
            product = settings.product
            tankSize = settings.tankSize
            if productChanged { history = nil }
            observe()
        }
    }

    private func watchLocation() async {
        guard await locateUser.status() == .authorized else { return }
        for await coordinate in await locateUser.updates() {
            if let origin, coordinate.distance(to: origin) < 50 { continue }
            origin = coordinate
            observe()
        }
    }
}

extension Station {
    /// Apple Maps link for Compartir, in the detail and the rows' menu.
    public var shareURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: name),
        ]
        return components?.url
    }
}
