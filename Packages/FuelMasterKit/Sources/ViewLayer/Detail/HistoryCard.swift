import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// "Últimos 7 días": the station's line in the accent, the dashed area average, and min / max / change.
struct HistoryCard: View {
    let chart: HistoryChart
    let provinceName: String
    let compact: Bool
    let onRetry: () -> Void

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Últimos 7 días", bundle: .module)
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if chart.isLoading { ProgressView().controlSize(.small) }
            }
            HistoryChartView(chart: chart, compact: compact)
                .frame(height: compact ? 100 : 160)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(chartSummary))
                .accessibilityChartDescriptor(audioGraph)
            HistoryLegend(provinceName: provinceName)
            if !compact { HistoryStats(chart: chart) }
            if chart.isIncomplete && !chart.isLoading {
                HStack {
                    Text("Faltan días: no se pudo descargar el historial.", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Spacer(minLength: 8)
                    Button(String(localized: "Reintentar", bundle: .module), action: onRetry)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Audio Graphs: VoiceOver can play the week as tones and step through each day.
    private var audioGraph: HistoryAudioGraph {
        HistoryAudioGraph(station: chart.stationPoints, average: chart.averagePoints, range: chart.range,
                          summary: chartSummary, averageName: String(localized: "Media de \(provinceName)", bundle: .module),
                          format: format)
    }

    /// «Últimos 7 días: entre 1,859 € y 1,879 €. Media de Madrid entre 1,923 € y 1,928 €.»
    private var chartSummary: String {
        var parts: [String] = []
        if let minimum = chart.minimum, let maximum = chart.maximum {
            parts.append(minimum == maximum
                ? String(localized: "Últimos 7 días: \(format.priceWithCurrency(minimum)) todos los días.", bundle: .module)
                : String(localized: "Últimos 7 días: entre \(format.priceWithCurrency(minimum)) y \(format.priceWithCurrency(maximum)).",
                         bundle: .module))
        }
        if let area = chart.areaRange {
            parts.append(String(localized: "Media de \(provinceName) entre \(format.priceWithCurrency(area.minimum)) y \(format.priceWithCurrency(area.maximum)).",
                                bundle: .module))
        }
        return parts.joined(separator: " ")
    }
}
