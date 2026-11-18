import Foundation

extension SearchQuery {
    public var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// What the search actually looks for: in "Todo", digits mean a postcode.
    public var resolvedScope: SearchScope {
        guard scope == .all else { return scope }
        return Self.isPostcode(trimmed) ? .postcode : .all
    }

    static func isPostcode(_ text: String) -> Bool {
        (2...5).contains(text.count) && text.allSatisfy { $0.isASCII && $0.isNumber }
    }
}

/// Which part of a result matched, so the row can highlight it.
public enum SearchMatch: Sendable, Equatable {
    case name
    case locality
    case postcode
}

public struct SearchHit: Sendable, Equatable, Identifiable {
    public let summary: StationSummary
    public let match: SearchMatch

    public init(summary: StationSummary, match: SearchMatch) {
        self.summary = summary
        self.match = match
    }

    public var id: StationID { summary.id }
}

public struct SearchResult: Sendable, Equatable {
    public let hits: [SearchHit]
    /// Nearest first when the user's position is known, cheapest first otherwise.
    public let sortedByDistance: Bool
    /// A province the search needed couldn't be loaded (offline or the ministry is down).
    public let loadFailure: DomainError?

    public init(hits: [SearchHit], sortedByDistance: Bool, loadFailure: DomainError?) {
        self.hits = hits
        self.sortedByDistance = sortedByDistance
        self.loadFailure = loadFailure
    }
}

/// Buscar (Bear note 07, SearchStations): brands within the user's area, and localities or
/// postcodes anywhere in Spain. A locality or postcode outside the cached provinces first loads
/// its province.
public struct SearchStations: Sendable {
    public static let maximumHits = 60

    private let cache: any StationCacheRepository
    private let provinces: any ProvinceRepository
    private let favorites: any FavoriteStationsRepository
    private let refreshPrices: RefreshPrices
    private let classify = ClassifyPrice()
    private let summarize = SummarizeArea()
    private let openingHours: EvaluateOpeningHours
    private let now: @Sendable () -> Date

    public init(cache: any StationCacheRepository, provinces: any ProvinceRepository,
                favorites: any FavoriteStationsRepository, refreshPrices: RefreshPrices,
                openingHours: EvaluateOpeningHours = EvaluateOpeningHours(),
                now: @escaping @Sendable () -> Date = { .now }) {
        self.cache = cache
        self.provinces = provinces
        self.favorites = favorites
        self.refreshPrices = refreshPrices
        self.openingHours = openingHours
        self.now = now
    }

    /// `area` is the provinces brands are searched in: the user's area.
    public func callAsFunction(_ query: SearchQuery, product: Product, area: [ProvinceID],
                               origin: Coordinate?) async throws -> SearchResult {
        let text = query.trimmed
        let needle = Self.fold(text)
        guard !needle.isEmpty else { return SearchResult(hits: [], sortedByDistance: origin != nil, loadFailure: nil) }
        let scope = query.resolvedScope

        // Provinces to look in, and to load first when they aren't cached yet.
        var searched = Set<ProvinceID>()
        if scope == .brand || scope == .all { searched.formUnion(area) }
        if scope == .locality || scope == .all {
            searched.formUnion(await provinces.municipalities(matching: text).prefix(20).map(\.provinceID))
        }
        if scope == .postcode, text.count >= 2 { searched.insert(ProvinceID(String(text.prefix(2)))) }
        let outcome = await refreshPrices(Array(searched))
        let loadFailure = outcome.failed.values.first

        let stations = try await cache.stations(in: Array(searched).sorted())
        let favoriteIDs = Set(try await favorites.favorites().map(\.stationID))
        let moment = now()
        var averages: [ProvinceID: Decimal] = [:]
        for province in searched {
            averages[province] = summarize(stations.filter { $0.provinceID == province }, product: product,
                                           provinces: [province], snapshotDate: nil)?.average
        }

        var hits: [SearchHit] = []
        for station in stations {
            guard let price = station.price(for: product),
                  let match = Self.match(station, needle: needle, text: text, scope: scope, area: area) else { continue }
            let summary = StationSummary(
                station: station, price: price,
                level: averages[station.provinceID].map { classify(price.amount, areaAverage: $0) } ?? .average,
                distance: origin.map { station.coordinate.distance(to: $0) },
                openingStatus: openingHours(station.hours, at: moment), isFavorite: favoriteIDs.contains(station.id)
            )
            hits.append(SearchHit(summary: summary, match: match))
        }
        hits.sort { lhs, rhs in
            if let l = lhs.summary.distance, let r = rhs.summary.distance, l != r { return l < r }
            return lhs.summary.price.amount < rhs.summary.price.amount
        }
        return SearchResult(hits: Array(hits.prefix(Self.maximumHits)), sortedByDistance: origin != nil,
                            loadFailure: hits.isEmpty ? loadFailure : nil)
    }

    static func match(_ station: Station, needle: String, text: String, scope: SearchScope,
                      area: [ProvinceID]) -> SearchMatch? {
        switch scope {
        case .postcode:
            return station.address.postcode.hasPrefix(text) ? .postcode : nil
        case .brand:
            return fold(station.name).contains(needle) && area.contains(station.provinceID) ? .name : nil
        case .locality:
            return matchesLocality(station, needle) ? .locality : nil
        case .all:
            if fold(station.name).contains(needle), area.contains(station.provinceID) { return .name }
            return matchesLocality(station, needle) ? .locality : nil
        }
    }

    private static func matchesLocality(_ station: Station, _ needle: String) -> Bool {
        fold(station.address.locality).contains(needle) || fold(station.address.municipality).contains(needle)
    }

    /// Case- and accent-insensitive form for matching ("Ávila" ~ "avila").
    public static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
