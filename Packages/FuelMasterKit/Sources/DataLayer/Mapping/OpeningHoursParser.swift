import DomainLayer
import Foundation

/// Reads the ministry's free-text hours, e.g. "L-D: 24H", "L-V: 07:00-21:00; S: 09:00-14:00",
/// "L-V: 07:00-14:00 y 16:00-21:00". 91 distinct shapes exist in the national dataset (Oct 2026);
/// anything that doesn't fit the grammar becomes `.unknown` and is shown as raw text.
public enum OpeningHoursParser {
    static let dayLetters: [Character: Weekday] = [
        "L": .monday, "M": .tuesday, "X": .wednesday, "J": .thursday, "V": .friday, "S": .saturday, "D": .sunday,
    ]

    public static func parse(_ raw: String) -> OpeningHours {
        let text = raw.trimmingCharacters(in: .whitespaces)
        return OpeningHours(rawText: text, schedule: schedule(text))
    }

    static func schedule(_ text: String) -> Schedule {
        guard !text.isEmpty else { return .unknown }
        var rules: [DayRule] = []
        for segment in text.split(separator: ";") {
            guard let rule = rule(String(segment)) else { return .unknown }
            rules.append(rule)
        }
        // About 480 stations publish only a Monday entry ("L: 24H", "L: 07:00-22:00"), which almost
        // certainly isn't what they mean. Rather than marking them closed six days a week, treat as unknown.
        let covered = rules.reduce(into: Set<Weekday>()) { $0.formUnion($1.days) }
        if covered == [.monday] { return .unknown }
        if covered == Set(Weekday.allCases), rules.allSatisfy(\.isAllDay) { return .alwaysOpen }
        return .weekly(rules)
    }

    static func rule(_ segment: String) -> DayRule? {
        let parts = segment.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let days = days(parts[0]) else { return nil }
        let times = parts[1]
        if times.uppercased() == "24H" { return DayRule(days: days, ranges: []) }
        var ranges: [TimeRange] = []
        for piece in times.components(separatedBy: " y ") {
            guard let range = range(piece.trimmingCharacters(in: .whitespaces)) else { return nil }
            ranges.append(range)
        }
        // "00:00-23:59" is a whole day.
        if ranges.count == 1, ranges[0].start == 0, ranges[0].end >= 23 * 60 + 59 {
            return DayRule(days: days, ranges: [])
        }
        return DayRule(days: days, ranges: ranges)
    }

    static func days(_ text: String) -> Set<Weekday>? {
        let letters = text.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = letters.first, first.count == 1, let start = dayLetters[Character(first)] else { return nil }
        if letters.count == 1 { return [start] }
        guard letters.count == 2, letters[1].count == 1, let end = dayLetters[Character(letters[1])] else { return nil }
        if start <= end {
            return Set(Weekday.allCases.filter { $0 >= start && $0 <= end })
        }
        // Wrapping ranges such as "S-L".
        return Set(Weekday.allCases.filter { $0 >= start || $0 <= end })
    }

    static func range(_ text: String) -> TimeRange? {
        let ends = text.split(separator: "-")
        guard ends.count == 2, let start = minutes(String(ends[0])), let end = minutes(String(ends[1])) else { return nil }
        return TimeRange(start: start, end: end)
    }

    static func minutes(_ text: String) -> Int? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0...24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return parts[0] * 60 + parts[1]
    }
}
