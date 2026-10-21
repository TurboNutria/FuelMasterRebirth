import Foundation

/// Works out whether a station is open at a given moment and when that changes next.
/// Opening hours are local to Spain, so evaluation uses the Madrid time zone by default.
public struct EvaluateOpeningHours: Sendable {
    private let calendar: Calendar

    public init(timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid")!) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    public func callAsFunction(_ hours: OpeningHours, at date: Date) -> OpeningStatus {
        switch hours.schedule {
        case .alwaysOpen:
            return .alwaysOpen
        case .unknown:
            return .unknown
        case .weekly(let rules):
            return evaluate(rules, at: date)
        }
    }

    private func evaluate(_ rules: [DayRule], at date: Date) -> OpeningStatus {
        let intervals = mergedIntervals(for: rules, around: date)
        if intervals.isEmpty { return .closed(opensAt: nil) }
        if let current = intervals.first(where: { $0.contains(date) }) {
            // Open for a whole week ahead means effectively always open.
            if current.end.timeIntervalSince(date) >= 7 * 24 * 3600 { return .alwaysOpen }
            return .open(closesAt: current.end)
        }
        return .closed(opensAt: intervals.first(where: { $0.start > date })?.start)
    }

    /// Absolute open intervals from yesterday to eight days ahead, with touching intervals merged
    /// (so "L-D: 00:00-23:59" reads as continuously open).
    private func mergedIntervals(for rules: [DayRule], around date: Date) -> [DateInterval] {
        let today = calendar.startOfDay(for: date)
        var raw: [DateInterval] = []
        for offset in -1...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: day))
            for rule in rules where rule.days.contains(weekday) {
                let ranges = rule.isAllDay ? [TimeRange(start: 0, end: 24 * 60)] : rule.ranges
                for range in ranges {
                    let start = day.addingTimeInterval(TimeInterval(range.start * 60))
                    let endMinutes = range.crossesMidnight ? range.end + 24 * 60 : range.end
                    // 23:59 means "until midnight".
                    let adjustedEnd = endMinutes % (24 * 60) == 23 * 60 + 59 ? endMinutes + 1 : endMinutes
                    let end = day.addingTimeInterval(TimeInterval(adjustedEnd * 60))
                    if end > start { raw.append(DateInterval(start: start, end: end)) }
                }
            }
        }
        raw.sort { $0.start < $1.start }
        var merged: [DateInterval] = []
        for interval in raw {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}

private extension DateInterval {
    /// Half-open containment: open at `start`, closed again at `end`.
    func contains(_ date: Date) -> Bool { date >= start && date < end }
}
