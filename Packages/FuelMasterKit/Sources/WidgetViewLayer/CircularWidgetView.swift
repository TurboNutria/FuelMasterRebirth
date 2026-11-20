import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

/// A gauge: the arc shows where the cheapest price falls between the area's cheapest and dearest.
public struct CircularWidgetView: View {
    let content: WidgetContent

    @Environment(\.displayFormat) private var format

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        Gauge(value: content.gaugeFraction ?? 0) {
            Image(systemName: "fuelpump.fill")
        } currentValueLabel: {
            Text(content.cheapest.map { shortPrice($0.price) } ?? "--")
                .font(.system(.body, design: .rounded, weight: .heavy))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
        .opacity(content.staleAge == nil ? 1 : 0.55)
        .widgetURL(content.cheapest?.link)
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: content.cheapest.map {
            "\($0.name), \(format.priceWithCurrency($0.price)), \($0.level.spokenName)"
        } ?? String(localized: "Sin precios", bundle: .module)))
    }

    /// "1,86": two decimals so it fits inside the ring.
    private func shortPrice(_ amount: Decimal) -> String {
        amount.formatted(.number.precision(.fractionLength(2)).locale(format.locale))
    }
}
#endif
