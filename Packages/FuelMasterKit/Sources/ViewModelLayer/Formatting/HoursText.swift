import DomainLayer
import Foundation

/// What a row shows for opening hours: today's hours plus open / closed now.
/// The View layer turns `today` into localised text ("24 h", "7:30–22:00", "Cerrada hoy").
public struct HoursSummary: Hashable, Sendable {
    public enum Today: Hashable, Sendable {
        case allDay
        /// Today's ranges, already formatted: "7:30–22:00" or "7:00–14:00, 16:00–21:00".
        case ranges(String)
        case closedAllDay
        /// The ministry text couldn't be read; shown as is, without colour.
        case unknown(raw: String)
    }

    public let today: Today
    public let status: OpeningStatus
    /// "7:30" when the status has a next change time.
    public let nextChange: String?
}

public enum HoursText {
    /// Ministry opening hours are local to Spain.
    public static let stationTimeZone = TimeZone(identifier: "Europe/Madrid")!

    public static func summary(for hours: OpeningHours, status: OpeningStatus, at date: Date,
                               format: DisplayFormat) -> HoursSummary {
        let nextChange: Date? = switch status {
        case .open(let closesAt): closesAt
        case .closed(let opensAt): opensAt
        case .alwaysOpen, .unknown: nil
        }
        return HoursSummary(today: today(for: hours, status: status, at: date, format: format),
                            status: status, nextChange: nextChange.map { format.time($0) })
    }

    private static func today(for hours: OpeningHours, status: OpeningStatus, at date: Date,
                              format: DisplayFormat) -> HoursSummary.Today {
        switch hours.schedule {
        case .alwaysOpen:
            return .allDay
        case .unknown:
            return .unknown(raw: hours.rawText)
        case .weekly(let rules):
            if status == .alwaysOpen { return .allDay }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = stationTimeZone
            let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: date))
            let todays = rules.filter { $0.days.contains(weekday) }
            if todays.isEmpty { return .closedAllDay }
            if todays.contains(where: \.isAllDay) { return .allDay }
            let startOfDay = calendar.startOfDay(for: date)
            let ranges = todays.flatMap(\.ranges).sorted { $0.start < $1.start }
            let text = ranges.map { range in
                let start = startOfDay.addingTimeInterval(TimeInterval(range.start * 60))
                let end = startOfDay.addingTimeInterval(TimeInterval(range.end * 60))
                return "\(format.time(start))–\(format.time(end))"
            }
            return .ranges(text.joined(separator: ", "))
        }
    }
}
