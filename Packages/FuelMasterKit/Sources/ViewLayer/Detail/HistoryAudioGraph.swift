import DesignTokens
import Accessibility
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The 7-day chart as data, for VoiceOver's Audio Graphs.
struct HistoryAudioGraph: AXChartDescriptorRepresentable {
    let station: [HistoryChart.Point]
    let average: [HistoryChart.Point]
    let range: ClosedRange<Double>
    let summary: String
    let averageName: String
    let format: DisplayFormat

    func makeChartDescriptor() -> AXChartDescriptor {
        let days = Array(Set((station + average).map(\.day))).sorted()
        let xAxis = AXCategoricalDataAxisDescriptor(title: String(localized: "Día", bundle: .module),
                                                    categoryOrder: days.map(label))
        let yAxis = AXNumericDataAxisDescriptor(title: String(localized: "Precio", bundle: .module), range: range,
                                                gridlinePositions: []) { value in
            format.priceWithCurrency(Decimal(value))
        }
        let series = [
            AXDataSeriesDescriptor(name: String(localized: "Esta estación", bundle: .module), isContinuous: true,
                                   dataPoints: station.map { AXDataPoint(x: label($0.day), y: $0.amount) }),
            AXDataSeriesDescriptor(name: averageName, isContinuous: true,
                                   dataPoints: average.map { AXDataPoint(x: label($0.day), y: $0.amount) }),
        ]
        return AXChartDescriptor(title: String(localized: "Últimos 7 días", bundle: .module), summary: summary,
                                 xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: series)
    }

    private func label(_ day: Date) -> String {
        format.day(day)
    }
}
