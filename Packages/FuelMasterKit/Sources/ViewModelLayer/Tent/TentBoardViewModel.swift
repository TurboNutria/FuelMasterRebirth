import DomainLayer
import Foundation
import Observation

/// One line of the board: a fuel, its price and the change since yesterday.
public struct TentBoardRow: Sendable, Equatable, Identifiable {
    public let product: Product
    public let amount: Decimal
    public let change: PriceChange?

    public var id: Product { product }
}

public struct TentBoardContent: Sendable, Equatable {
    public let detail: StationDetail
    public let hours: HoursSummary
    public let rows: [TentBoardRow]

    public var station: Station { detail.station }
    public var isClosed: Bool {
        if case .closed = detail.openingStatus { return true }
        return false
    }
    public var opensAt: Date? {
        if case .closed(let opensAt) = detail.openingStatus { return opensAt }
        return nil
    }
}

/// The price board for the closed iPhone Duo in landscape ("tent", canvas: Tent Price Board): one
/// station's prices like a forecourt sign. The view picks the station (the selected one, or the
/// cheapest open one nearby from Gasolineras); this loads its fuels and their change since
/// yesterday.
@MainActor @Observable
public final class TentBoardViewModel {
    /// A sign shows three lines.
    public static let maximumRows = 3
    /// After the chosen fuel, the ones a forecourt sign usually lists.
    static let preferredOrder: [Product] = [
        .diesel, .petrol95E5, .petrol98E5, .dieselPremium, .petrol95Premium,
        .lpg, .renewableDiesel, .cng, .lng, .adBlue,
    ]

    public private(set) var content: TentBoardContent?

    private var detail: StationDetail?
    private var changes: [Product: PriceChange] = [:]
    @ObservationIgnored private var historyKey: StationID?

    private let getDetail: GetStationDetail
    private let getHistory: GetPriceHistory
    private let backfillHistory: BackfillHistory
    private let format: DisplayFormat
    private let now: @Sendable () -> Date

    public init(getDetail: GetStationDetail, getHistory: GetPriceHistory, backfillHistory: BackfillHistory,
                format: DisplayFormat = DisplayFormat(), now: @escaping @Sendable () -> Date = { .now }) {
        self.getDetail = getDetail
        self.getHistory = getHistory
        self.backfillHistory = backfillHistory
        self.format = format
        self.now = now
    }

    /// The fuels to show: the chosen one first, then the usual sign order, only those sold here.
    public static func products(for station: Station, chosen: Product) -> [Product] {
        let ordered = [chosen] + preferredOrder.filter { $0 != chosen }
        return Array(ordered.filter { station.price(for: $0) != nil }.prefix(maximumRows))
    }

    /// Runs while the board shows this station (call it from `.task(id:)`).
    public func show(_ id: StationID, product: Product, tankSize: Decimal) async {
        if historyKey != id {
            changes = [:]
            content = nil
        }
        let request = StationDetailRequest(stationID: id, product: product, tankSize: tankSize)
        for await next in getDetail(request) {
            guard !Task.isCancelled else { return }
            detail = next
            rebuild(product: product)
            if let next, historyKey != id {
                historyKey = id
                await loadChanges(for: next.station, product: product)
                rebuild(product: product)
            }
        }
    }

    private func rebuild(product: Product) {
        guard let detail else {
            content = nil
            return
        }
        let rows = Self.products(for: detail.station, chosen: product).compactMap { fuel in
            detail.station.price(for: fuel).map { TentBoardRow(product: fuel, amount: $0.amount, change: changes[fuel]) }
        }
        content = TentBoardContent(
            detail: detail,
            hours: HoursText.summary(for: detail.station.hours, status: detail.openingStatus, at: now(), format: format),
            rows: rows
        )
    }

    /// Today against yesterday for each row. Yesterday is fetched when missing: one request per
    /// fuel, for the station's province.
    private func loadChanges(for station: Station, product: Product) async {
        for fuel in Self.products(for: station, chosen: product) {
            try? await backfillHistory(province: station.provinceID, product: fuel, recentDays: 1)
            guard let history = try? await getHistory.cached(station: station.id, product: fuel),
                  history.points.count >= 2,
                  let today = history.points[history.points.count - 1].amount,
                  let yesterday = history.points[history.points.count - 2].amount else { continue }
            changes[fuel] = PriceChange(difference: today - yesterday, comparedDay: history.points[history.points.count - 2].day)
        }
    }
}
