@testable import DataLayer
import DomainLayer
import Foundation
import Testing

@Suite("Text clean-up")
struct TextNormalizerTests {
    @Test(arguments: [
        ("CALLE ALBERTO AGUILERA, 18", "C/ Alberto Aguilera, 18"),
        ("CL ANCORA 39", "C/ Ancora 39"),
        ("CARRETERA M-114 KM. 1", "Ctra. M-114 km 1"),
        ("PASEO SANTA MARIA DE LA CABEZA, 90", "P.º Santa Maria de la Cabeza, 90"),
        ("AVENIDA DOCTOR ESQUERDO, 153", "Av. Doctor Esquerdo, 153"),
        ("GLORIETA EMBAJADORES, 0", "Glta. Embajadores, 0"),
        ("RONDA SEGOVIA, 37", "Ronda Segovia, 37"),
        ("CALLE ISAAC PERAL, S/N", "C/ Isaac Peral, s/n"),
        ("  PLAZA   LEGAZPI, 9 ", "Pl. Legazpi, 9"),
    ])
    func addresses(raw: String, expected: String) {
        #expect(TextNormalizer.address(raw) == expected)
    }

    @Test(arguments: [
        ("REPSOL", "Repsol"),
        ("BALLENOIL", "Ballenoil"),
        ("BP", "BP"),
        ("E.LECLERC", "E.Leclerc"),
        ("ESTACION DE SERVICIO LA RAYA", "Estacion de Servicio la Raya"),
        ("BALEARS (ILLES)", "Balears (Illes)"),
        ("AJALVIR                  ", "Ajalvir"),
    ])
    func names(raw: String, expected: String) {
        #expect(TextNormalizer.name(raw) == expected)
    }
}

@Suite("Opening hours parser")
struct OpeningHoursParserTests {
    @Test func twentyFourHoursEveryDayIsAlwaysOpen() {
        #expect(OpeningHoursParser.parse("L-D: 24H").schedule == .alwaysOpen)
        #expect(OpeningHoursParser.parse("L-D: 00:00-23:59").schedule == .alwaysOpen)
    }

    @Test func multipleSegmentsAndSplitShifts() throws {
        guard case .weekly(let rules) = OpeningHoursParser.parse("L-V: 07:00-14:00 y 16:00-21:00; S: 09:00-14:00").schedule else {
            Issue.record("expected a weekly schedule")
            return
        }
        #expect(rules.count == 2)
        #expect(rules[0].days.count == 5)
        #expect(rules[0].ranges == [TimeRange(start: 420, end: 840), TimeRange(start: 960, end: 1260)])
        #expect(rules[1].days == [.saturday])
    }

    @Test func mondayOnlyEntriesAreTreatedAsUnknown() {
        #expect(OpeningHoursParser.parse("L: 24H").schedule == .unknown)
        #expect(OpeningHoursParser.parse("L: 07:00-22:00").schedule == .unknown)
    }

    @Test func malformedTextIsUnknown() {
        #expect(OpeningHoursParser.parse("").schedule == .unknown)
        #expect(OpeningHoursParser.parse("Consultar").schedule == .unknown)
        #expect(OpeningHoursParser.parse("L-D: 7h-22h").schedule == .unknown)
    }

    @Test func everyRealFormatInMadridParses() throws {
        let list = try FixtureLoader.stationList("EstacionesTerrestres_FiltroProvincia_28")
        let schedules = list.stations.map { OpeningHoursParser.parse($0.hours).schedule }
        let unknown = schedules.filter { $0 == .unknown }.count
        // Only the Monday-only entries should end up unknown.
        #expect(Double(unknown) / Double(schedules.count) < 0.06)
    }
}

@Suite("URLs and values")
struct ValueTests {
    @Test func historyURLUsesMadridDayFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = MinistryDates.timeZone
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19))!
        let url = NetworkRepository().history(province: ProvinceID("28"), product: .diesel, day: day).url.absoluteString
        #expect(url.hasSuffix("EstacionesTerrestresHist/FiltroProvinciaProducto/19-10-2026/28/4"))
    }

    @Test func parsesMinistryNumbersAndDates() throws {
        #expect(MinistryNumbers.decimal("1,859") == Decimal(string: "1.859"))
        #expect(MinistryNumbers.decimal("") == nil)
        let date = try #require(MinistryDates.parse("20/10/2026 17:28:49"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = MinistryDates.timeZone
        #expect(calendar.dateComponents([.hour, .minute, .day], from: date) == DateComponents(day: 20, hour: 17, minute: 28))
        #expect(MinistryDates.parse("19/10/2026 0:00:00") != nil)
    }

    @Test func petrolCoversItsE10Blend() throws {
        let base = ["IDEESS": "1", "Rótulo": "TEST", "Latitud": "40,4169", "Longitud (WGS84)": "-3,7035", "Tipo Venta": "P"]
        let onlyE10 = try #require(StationMapper.station(from: StationDTO(fields: base.merging(
            ["Precio Gasolina 95 E10": "1,599"]) { $1 })))
        #expect(onlyE10.price(for: .petrol95E5)?.amount == Decimal(string: "1.599"))
        let both = try #require(StationMapper.station(from: StationDTO(fields: base.merging(
            ["Precio Gasolina 95 E5": "1,649", "Precio Gasolina 95 E10": "1,599"]) { $1 })))
        #expect(both.price(for: .petrol95E5)?.amount == Decimal(string: "1.649"))
    }

    @Test func savedE10ChoicesReadAsPlainPetrol() throws {
        let products = try JSONDecoder().decode([Product].self, from: Data("[23, 21, 4]".utf8))
        #expect(products == [.petrol95E5, .petrol98E5, .diesel])
    }
}
