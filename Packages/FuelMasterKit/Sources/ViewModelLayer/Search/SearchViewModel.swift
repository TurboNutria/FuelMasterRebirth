import DomainLayer
import Foundation
import Observation

public struct SearchRow: Sendable, Equatable, Identifiable {
    public let hit: SearchHit
    public let hours: HoursSummary

    public var id: StationID { hit.id }
    public var summary: StationSummary { hit.summary }
}

public struct SearchContent: Sendable, Equatable {
    public let rows: [SearchRow]
    /// The text and scope these results are for, for the summary line and the highlight.
    public let text: String
    public let scope: SearchScope
    public let sortedByDistance: Bool
    /// "Madrid" when there's no location and brands are searched in the default province.
    public let areaName: String?
}

/// Buscar (Bear note 07, section 5): brand, locality or postcode, with scopes, nearest first and
/// the match highlighted. Searches a short pause after the user stops typing.
@MainActor @Observable
public final class SearchViewModel {
    public var text = "" {
        didSet { if text != oldValue { schedule() } }
    }
    public var scope: SearchScope = .all {
        didSet { if scope != oldValue { schedule(immediately: true) } }
    }

    private var content: SearchContent?
    private var isSearching = false
    private var failure: DomainError?
    private var product: Product = .diesel
    private var area: [ProvinceID] = []
    private var areaName: String?
    private var origin: Coordinate?
    private var activeRuns = 0
    @ObservationIgnored private var pending: Task<Void, Never>?

    private let searchStations: SearchStations
    private let resolveArea: ResolveArea
    private let toggleFavorite: ToggleFavorite
    private let observeSettings: ObserveSettings
    private let locateUser: LocateUser
    private let format: DisplayFormat
    private let debounce: Duration
    private let now: @Sendable () -> Date

    public init(searchStations: SearchStations, resolveArea: ResolveArea, toggleFavorite: ToggleFavorite,
                observeSettings: ObserveSettings, locateUser: LocateUser, format: DisplayFormat = DisplayFormat(),
                debounce: Duration = .milliseconds(300), now: @escaping @Sendable () -> Date = { .now }) {
        self.searchStations = searchStations
        self.resolveArea = resolveArea
        self.toggleFavorite = toggleFavorite
        self.observeSettings = observeSettings
        self.locateUser = locateUser
        self.format = format
        self.debounce = debounce
        self.now = now
    }

    // MARK: State

    /// Nothing typed yet.
    public var isIdle: Bool { SearchQuery(text: text, scope: scope).trimmed.isEmpty }

    public var state: ScreenState<SearchContent> {
        if let failure, content == nil { return .failed(failure) }
        guard let content else { return .firstLoad }
        if content.rows.isEmpty { return isSearching ? .firstLoad : .empty(.noSearchResults(content.text)) }
        return isSearching ? .updating(content) : .content(content)
    }

    // MARK: Intents

    /// Runs while Buscar is on screen: works out the area brands are searched in.
    public func start() async {
        activeRuns += 1
        let settings = await observeSettings.current()
        product = settings.product
        if area.isEmpty {
            await locate(settings: settings)
            // Anything typed while locating waited for the area.
            if !isIdle { schedule(immediately: true) }
        }
        for await settings in await observeSettings() where settings.product != product {
            product = settings.product
            schedule(immediately: true)
        }
        activeRuns -= 1
        if activeRuns == 0 { pending?.cancel() }
    }

    public func retry() {
        schedule(immediately: true)
    }

    public func toggleFavorite(_ summary: StationSummary) async {
        _ = try? await toggleFavorite(summary.station.id, province: summary.station.provinceID)
        // Re-runs the search so the star follows.
        schedule(immediately: true)
    }

    // MARK: Searching

    private func locate(settings: Settings) async {
        if await locateUser.status() == .authorized, let fix = await locateUser.firstFix() {
            origin = fix
            area = await resolveArea(around: fix).provinces
            areaName = nil
            return
        }
        let id = ResolveArea.province(for: settings)
        let resolved = await resolveArea(province: id)
        area = resolved?.provinces ?? [id]
        areaName = resolved?.provinceName
    }

    private func schedule(immediately: Bool = false) {
        pending?.cancel()
        let query = SearchQuery(text: text, scope: scope)
        guard !query.trimmed.isEmpty else {
            content = nil
            failure = nil
            isSearching = false
            return
        }
        isSearching = true
        pending = Task { [debounce] in
            if !immediately { try? await Task.sleep(for: debounce) }
            // Until the area is known, brands would search nowhere; `start()` runs it then.
            guard !Task.isCancelled, !area.isEmpty else { return }
            await run(query)
        }
    }

    private func run(_ query: SearchQuery) async {
        do {
            let result = try await searchStations(query, product: product, area: area, origin: origin)
            guard !Task.isCancelled, query == SearchQuery(text: text, scope: scope) else { return }
            let moment = now()
            if let error = result.loadFailure, result.hits.isEmpty {
                content = nil
                failure = error
            } else {
                failure = nil
                content = SearchContent(
                    rows: result.hits.map { hit in
                        SearchRow(hit: hit, hours: HoursText.summary(for: hit.summary.station.hours,
                                                                     status: hit.summary.openingStatus, at: moment, format: format))
                    },
                    text: query.trimmed, scope: query.resolvedScope, sortedByDistance: result.sortedByDistance,
                    areaName: origin == nil ? areaName : nil
                )
            }
        } catch {
            guard !Task.isCancelled else { return }
            content = nil
            failure = .unreadableResponse
        }
        isSearching = false
    }
}
