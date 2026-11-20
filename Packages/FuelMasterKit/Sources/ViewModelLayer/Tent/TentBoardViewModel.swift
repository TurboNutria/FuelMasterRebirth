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

/// When a closed station opens again, ready for the board.
public struct TentReopening: Sendable, Equatable {
    public enum Day: Sendable, Equatable {
        case today
        case tomorrow
        /// "martes".
        case weekday(String)
    }

    public let day: Day
    /// "7:30", following the locale's 12/24-hour setting (VoiceOver).
    public let time: String
    /// "06:00" in 24-hour time whatever the device setting: signs don't do am / pm.
    public let signTime: String
}

public struct TentBoardContent: Sendable, Equatable {
    public let detail: StationDetail
    public let hours: HoursSummary
    public let rows: [TentBoardRow]
    /// Nil while open, or when the next opening isn't known.
    public let reopening: TentReopening?

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
/// station's prices like a forecourt sign. `TentBoardChoice` picks the station (the selected one,
/// or the cheapest open one nearby from Gasolineras); this loads its fuels and their change since
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
    private let getPriceChanges: GetPriceChanges
    private let format: DisplayFormat
    private let now: @Sendable () -> Date

    public init(getDetail: GetStationDetail, getPriceChanges: GetPriceChanges,
                format: DisplayFormat = DisplayFormat(), now: @escaping @Sendable () -> Date = { .now }) {
        self.getDetail = getDetail
        self.getPriceChanges = getPriceChanges
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
                changes = await getPriceChanges(next.station, products: Self.products(for: next.station, chosen: product))
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
            rows: rows,
            reopening: {
                guard case .closed(let opensAt?) = detail.openingStatus else { return nil }
                return Self.reopening(at: opensAt, now: now(), format: format)
            }()
        )
    }

    public static func reopening(at date: Date, now: Date, format: DisplayFormat) -> TentReopening {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = HoursText.stationTimeZone
        let today = calendar.startOfDay(for: now)
        let day: TentReopening.Day = switch calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day {
        case 0: .today
        case 1: .tomorrow
        default: .weekday(format.weekday(date))
        }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return TentReopening(day: day, time: format.time(date),
                             signTime: String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0))
    }
}
