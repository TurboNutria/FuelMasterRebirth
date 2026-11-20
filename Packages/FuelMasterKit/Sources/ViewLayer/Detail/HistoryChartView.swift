import Charts
import DesignTokens
import SwiftUI
import ViewModelLayer

/// The 7-day chart itself: the station's line over a soft fill in the accent, and the area's
/// average dashed. `compact` (the inspector) drops the axis labels.
struct HistoryChartView: View {
    let chart: HistoryChart
    let compact: Bool

    @Environment(\.displayFormat) private var format
    @Environment(\.accentColors) private var accent

    var body: some View {
        Chart {
            ForEach(chart.stationPoints, id: \.day) { point in
                AreaMark(x: .value("Día", point.day, unit: .day),
                         yStart: .value("Precio", chart.range.lowerBound), yEnd: .value("Precio", point.amount),
                         series: .value("Serie", "station"))
                    .foregroundStyle(LinearGradient(colors: [accent.tint.opacity(0.18), accent.tint.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Día", point.day, unit: .day), y: .value("Precio", point.amount),
                         series: .value("Serie", "station"))
                    .foregroundStyle(accent.tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            ForEach(chart.averagePoints, id: \.day) { point in
                LineMark(x: .value("Día", point.day, unit: .day), y: .value("Precio", point.amount),
                         series: .value("Serie", "average"))
                    .foregroundStyle(ColorTokens.closed)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
        .chartYScale(domain: chart.range)
        .chartXAxis {
            if compact {
                AxisMarks { _ in }
            } else {
                AxisMarks(values: chart.axisDays) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(format.locale))
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(ColorTokens.separator)
                if !compact, let amount = value.as(Double.self) {
                    AxisValueLabel(amount.formatted(.number.precision(.fractionLength(2)).locale(format.locale)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }
}
