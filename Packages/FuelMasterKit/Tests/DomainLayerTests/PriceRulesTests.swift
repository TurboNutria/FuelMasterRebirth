import DomainLayer
import Foundation
import Testing

@Suite("Price rules")
struct PriceRulesTests {
    let classify = ClassifyPrice()

    // Madrid city, diesel, 20/10/2026: average 1,924 €.
    @Test(arguments: [
        ("1.859", PriceLevel.cheap),
        ("1.864", .cheap),      // exactly average − 0,06
        ("1.865", .average),
        ("1.929", .average),
        ("1.983", .average),
        ("1.984", .expensive),  // exactly average + 0,06
        ("2.019", .expensive),
    ])
    func classifiesAgainstTheFixedBand(price: String, expected: PriceLevel) {
        #expect(classify(Decimal(string: price)!, areaAverage: Decimal(string: "1.924")!) == expected)
    }

    @Test func fullTankCostIsRoundedToCents() throws {
        let cost = try #require(CalculateFuelCost()(price: Price(amount: Decimal(string: "1.859")!, product: .diesel), tankSize: 55))
        #expect(cost.amount == Decimal(string: "102.25")!)
        #expect(cost.unit == .litre)
    }

    @Test func naturalGasIsCostedInKilograms() throws {
        let cost = try #require(CalculateFuelCost()(price: Price(amount: Decimal(string: "1.299")!, product: .cng), tankSize: 15))
        #expect(cost.unit == .kilogram)
    }

    @Test func adBlueHasNoTankCost() {
        #expect(CalculateFuelCost()(price: Price(amount: 1, product: .adBlue), tankSize: 55) == nil)
    }

    @Test func areaSummaryUsesOnlyStationsSellingTheProduct() throws {
        let stations = [
            Fixtures.station("1", diesel: "1.800"),
            Fixtures.station("2", diesel: "2.000"),
            Fixtures.station("3", diesel: nil),
        ]
        let summary = try #require(SummarizeArea()(stations, product: .diesel, provinces: [ProvinceID("28")], snapshotDate: nil))
        #expect(summary.average == Decimal(string: "1.9")!)
        #expect(summary.minimum == Decimal(string: "1.8")!)
        #expect(summary.stationCount == 2)
    }
}
