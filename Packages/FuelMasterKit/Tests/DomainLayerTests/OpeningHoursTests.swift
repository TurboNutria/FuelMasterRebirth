import DomainLayer
import Foundation
import Testing

@Suite("Opening hours evaluation")
struct OpeningHoursTests {
    let evaluate = EvaluateOpeningHours()
    // Tuesday 20 October 2026, 22:30 in Madrid: the mock time used on the design canvas.
    let tuesdayNight = Fixtures.date(2026, 10, 20, 22, 30)

    let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    @Test func closedAfterHoursOpensNextMorning() {
        let hours = OpeningHours(rawText: "L-V: 07:30-22:00", schedule: .weekly([
            DayRule(days: weekdays, ranges: [TimeRange(start: 7 * 60 + 30, end: 22 * 60)]),
        ]))
        #expect(evaluate(hours, at: tuesdayNight) == .closed(opensAt: Fixtures.date(2026, 10, 21, 7, 30)))
    }

    @Test func openUntilClosingTime() {
        let hours = OpeningHours(rawText: "L-D: 07:00-23:00", schedule: .weekly([
            DayRule(days: Set(Weekday.allCases), ranges: [TimeRange(start: 7 * 60, end: 23 * 60)]),
        ]))
        #expect(evaluate(hours, at: tuesdayNight) == .open(closesAt: Fixtures.date(2026, 10, 20, 23, 0)))
    }

    @Test func fridayAfternoonClosedOpensMonday() {
        // Closed at weekends: Friday 21:30 → next opening Monday 07:30.
        let hours = OpeningHours(rawText: "L-V: 07:30-21:00", schedule: .weekly([
            DayRule(days: weekdays, ranges: [TimeRange(start: 7 * 60 + 30, end: 21 * 60)]),
        ]))
        let friday = Fixtures.date(2026, 10, 23, 21, 30)
        #expect(evaluate(hours, at: friday) == .closed(opensAt: Fixtures.date(2026, 10, 26, 7, 30)))
    }

    @Test func splitShiftIsClosedAtLunch() {
        let hours = OpeningHours(rawText: "L-V: 07:00-14:00 y 16:00-21:00", schedule: .weekly([
            DayRule(days: weekdays, ranges: [TimeRange(start: 7 * 60, end: 14 * 60), TimeRange(start: 16 * 60, end: 21 * 60)]),
        ]))
        #expect(evaluate(hours, at: Fixtures.date(2026, 10, 20, 15, 0)) == .closed(opensAt: Fixtures.date(2026, 10, 20, 16, 0)))
    }

    @Test func overnightRangeIsOpenAfterMidnight() {
        let hours = OpeningHours(rawText: "L-D: 22:00-06:00", schedule: .weekly([
            DayRule(days: Set(Weekday.allCases), ranges: [TimeRange(start: 22 * 60, end: 6 * 60)]),
        ]))
        #expect(evaluate(hours, at: Fixtures.date(2026, 10, 21, 2, 0)).isOpen)
    }

    @Test func alwaysOpenAndUnknownPassThrough() {
        #expect(evaluate(OpeningHours(rawText: "L-D: 24H", schedule: .alwaysOpen), at: tuesdayNight) == .alwaysOpen)
        #expect(evaluate(OpeningHours(rawText: "?", schedule: .unknown), at: tuesdayNight) == .unknown)
    }

    @Test func weekdayMappingFromCalendar() {
        #expect(Weekday(calendarWeekday: 1) == .sunday)
        #expect(Weekday(calendarWeekday: 2) == .monday)
        #expect(Weekday(calendarWeekday: 7) == .saturday)
    }
}
