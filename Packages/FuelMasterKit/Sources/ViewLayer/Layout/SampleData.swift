import DomainLayer
import SwiftUI
import ViewModelLayer

/// Sample stations from the canvas (Madrid, Tuesday 20 October 2026, 22:30), for previews.
enum SampleData {
    static let now: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = HoursText.stationTimeZone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 22, minute: 30))!
    }()

    static let summaries: [StationSummary] = [
        summary("1", "Ballenoil", "Ronda de Segovia, 37", "1.859", .cheap, 1400, .alwaysOpen, favourite: true),
        summary("2", "Blanca", "Glorieta de Embajadores", "1.879", .average, 1300,
                .weekly([DayRule(days: Set(Weekday.allCases), ranges: [TimeRange(start: 450, end: 1320)])])),
        summary("3", "Shell", "C/ Goya, 24", "1.934", .average, 2000,
                .weekly([DayRule(days: Set(Weekday.allCases), ranges: [TimeRange(start: 420, end: 1380)])])),
        summary("4", "Cepsa", "Embajadores, 83", "1.969", .expensive, 1700, .alwaysOpen),
    ]

    private static func summary(_ id: String, _ name: String, _ street: String, _ price: String, _ level: PriceLevel,
                                _ distance: Double, _ schedule: Schedule, favourite: Bool = false) -> StationSummary {
        let hours = OpeningHours(rawText: "", schedule: schedule)
        let amount = Price(amount: Decimal(string: price)!, product: .diesel)
        let station = Station(
            id: StationID(id), name: name,
            address: Address(street: street, postcode: "28005", locality: "Madrid", municipality: "Madrid", province: "Madrid"),
            coordinate: Coordinate(latitude: 40.40, longitude: -3.70), roadSide: .notApplicable, hours: hours,
            provinceID: ProvinceID("28"), municipalityID: MunicipalityID("4354"), prices: [.diesel: amount]
        )
        return StationSummary(station: station, price: amount, level: level, distance: distance,
                              openingStatus: EvaluateOpeningHours()(hours, at: now), isFavorite: favourite)
    }
}

#Preview("Rows (sample)") {
    VStack(spacing: 0) {
        ForEach(SampleData.summaries) { summary in
            StationRow(summary, hours: HoursText.summary(for: summary.station.hours, status: summary.openingStatus,
                                                         at: SampleData.now, format: DisplayFormat()))
        }
    }
    .padding()
}
