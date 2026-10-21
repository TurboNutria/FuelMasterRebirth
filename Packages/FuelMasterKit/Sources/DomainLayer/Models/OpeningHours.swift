import Foundation

/// Days as the ministry writes them (L, M, X, J, V, S, D), Monday first.
public enum Weekday: Int, CaseIterable, Sendable, Codable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    /// Converts from `Calendar` weekday numbering, where Sunday is 1.
    public init(calendarWeekday: Int) {
        self = Weekday(rawValue: (calendarWeekday + 5) % 7 + 1) ?? .monday
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Minutes since midnight. `end` may be 1440 for "until midnight".
public struct TimeRange: Hashable, Sendable, Codable {
    public let start: Int
    public let end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    /// True when the range runs past midnight, e.g. 22:00–06:00.
    public var crossesMidnight: Bool { end <= start }
}

public struct DayRule: Hashable, Sendable, Codable {
    public let days: Set<Weekday>
    /// Empty means open all day on these days.
    public let ranges: [TimeRange]

    public init(days: Set<Weekday>, ranges: [TimeRange]) {
        self.days = days
        self.ranges = ranges
    }

    public var isAllDay: Bool { ranges.isEmpty }
}

public enum Schedule: Hashable, Sendable, Codable {
    case alwaysOpen
    case weekly([DayRule])
    /// The text couldn't be read reliably; the app shows it as is, without colour.
    case unknown
}

public struct OpeningHours: Hashable, Sendable, Codable {
    public let rawText: String
    public let schedule: Schedule

    public init(rawText: String, schedule: Schedule) {
        self.rawText = rawText
        self.schedule = schedule
    }
}

public enum OpeningStatus: Hashable, Sendable {
    case alwaysOpen
    case open(closesAt: Date?)
    case closed(opensAt: Date?)
    case unknown

    public var isOpen: Bool {
        switch self {
        case .alwaysOpen, .open: true
        case .closed, .unknown: false
        }
    }
}
