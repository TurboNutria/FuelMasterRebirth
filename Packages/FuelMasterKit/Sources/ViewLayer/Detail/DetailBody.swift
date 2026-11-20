import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The scrolling part of the detail: open sections on the page, no cards. `compact` is the
/// narrower inspector, which drops the chart's axis labels and the stats.
struct DetailBody: View {
    let content: StationDetailContent
    let compact: Bool
    let onRetryHistory: () -> Void

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            DetailHeader(content: content)
            PriceCard(detail: content.detail, product: content.product)
            // Without a price here the chart would only show the area line.
            if let chart = content.chart, content.detail.price != nil {
                HistoryCard(chart: chart, provinceName: content.station.address.province, compact: compact,
                            onRetry: onRetryHistory)
            }
            if !content.detail.otherPrices.isEmpty {
                OtherPricesCard(prices: content.detail.otherPrices)
            }
            if let freshness = content.detail.freshness {
                Text("Actualizado \(format.relativeTimeInSentence(freshness.snapshotDate, now: .now))", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
