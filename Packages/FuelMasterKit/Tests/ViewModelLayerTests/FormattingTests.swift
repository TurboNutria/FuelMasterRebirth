import DomainLayer
import Foundation
import Testing
import ViewModelLayer

@Suite("Display formatting")
struct FormattingTests {
    let spanish = DisplayFormat(locale: Locale(identifier: "es_ES"))
    let british = DisplayFormat(locale: Locale(identifier: "en_GB"))
    let now = Date(timeIntervalSince1970: 1_792_000_000)

    @Test func pricesKeepThreeDecimals() {
        #expect(spanish.price(Decimal(string: "1.859")!) == "1,859")
        #expect(spanish.price(Decimal(string: "1.9")!) == "1,900")
        #expect(british.price(Decimal(string: "1.859")!) == "1.859")
    }

    /// Spanish puts a no-break space before the euro sign.
    @Test func pricesWithCurrencyAreAlwaysEuros() {
        #expect(spanish.priceWithCurrency(Decimal(string: "1.859")!) == "1,859\u{00A0}€")
        #expect(british.priceWithCurrency(Decimal(string: "1.859")!) == "€1.859")
        #expect(spanish.money(Decimal(string: "102.245")!) == "102,25\u{00A0}€")
    }

    @Test func metricDistances() {
        #expect(spanish.distance(meters: 1400) == "1,4 km")
        #expect(spanish.distance(meters: 3000) == "3 km")
        #expect(spanish.distance(meters: 847) == "850 m")
        #expect(spanish.distance(meters: 3) == "10 m")
        #expect(spanish.distance(meters: 152_300) == "152 km")
    }

    @Test func britishRoadDistancesAreMiles() {
        #expect(british.distance(meters: 1609.344 * 2.5) == "2.5 mi")
    }

    @Test func relativeTimeForFreshness() {
        #expect(spanish.relativeTime(now.addingTimeInterval(-12 * 60), now: now) == "Hace 12 min")
        #expect(spanish.relativeTime(now.addingTimeInterval(-20), now: now) == "Ahora")
        #expect(spanish.relativeTimeInSentence(now.addingTimeInterval(-2 * 3600), now: now) == "hace 2 h")
        #expect(british.relativeTime(now.addingTimeInterval(-12 * 60), now: now) == "12 min ago")
    }

    @Test func timesFollowTheLocaleClock() {
        let morning = Fixtures.date(2026, 10, 20, 7, 30)
        #expect(spanish.time(morning) == "7:30")
        #expect(british.time(morning).hasSuffix("7:30"))
        #expect(!british.time(morning).localizedCaseInsensitiveContains("am"))
    }
}

@Suite("Opening hours text")
struct HoursTextTests {
    let format = DisplayFormat(locale: Locale(identifier: "es_ES"))
    let tuesdayNight = Fixtures.date(2026, 10, 20, 22, 30)
    let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    @Test func alwaysOpenReads24h() {
        let hours = OpeningHours(rawText: "L-D: 24H", schedule: .alwaysOpen)
        let summary = HoursText.summary(for: hours, status: .alwaysOpen, at: tuesdayNight, format: format)
        #expect(summary.today == .allDay)
        #expect(summary.nextChange == nil)
    }

    @Test func closedShowsTodaysRangeAndNextOpening() {
        let hours = OpeningHours(rawText: "L-V: 07:30-22:00", schedule: .weekly([
            DayRule(days: weekdays, ranges: [TimeRange(start: 7 * 60 + 30, end: 22 * 60)]),
        ]))
        let status = OpeningStatus.closed(opensAt: Fixtures.date(2026, 10, 21, 7, 30))
        let summary = HoursText.summary(for: hours, status: status, at: tuesdayNight, format: format)
        #expect(summary.today == .ranges("7:30–22:00"))
        #expect(summary.nextChange == "7:30")
    }

    @Test func splitShiftListsBothRanges() {
        let hours = OpeningHours(rawText: "L-V: 07:00-14:00 y 16:00-21:00", schedule: .weekly([
            DayRule(days: weekdays, ranges: [TimeRange(start: 16 * 60, end: 21 * 60), TimeRange(start: 7 * 60, end: 14 * 60)]),
        ]))
        let summary = HoursText.summary(for: hours, status: .closed(opensAt: nil), at: tuesdayNight, format: format)
        #expect(summary.today == .ranges("7:00–14:00, 16:00–21:00"))
    }

    @Test func noRuleTodayIsClosedAllDay() {
        let hours = OpeningHours(rawText: "L-V: 07:30-22:00", schedule: .weekly([
            DayRule(days: weekdays, ranges: [TimeRange(start: 7 * 60 + 30, end: 22 * 60)]),
        ]))
        let sunday = Fixtures.date(2026, 10, 25, 12, 0)
        let summary = HoursText.summary(for: hours, status: .closed(opensAt: nil), at: sunday, format: format)
        #expect(summary.today == .closedAllDay)
    }

    @Test func unreadableTextIsShownAsIs() {
        let hours = OpeningHours(rawText: "L: 24H", schedule: .unknown)
        let summary = HoursText.summary(for: hours, status: .unknown, at: tuesdayNight, format: format)
        #expect(summary.today == .unknown(raw: "L: 24H"))
    }
}

enum Fixtures {
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = HoursText.stationTimeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
