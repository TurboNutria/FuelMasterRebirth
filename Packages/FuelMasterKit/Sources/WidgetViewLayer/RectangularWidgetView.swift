import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

/// «Ballenoil · 1,4 km / 1,859 € / ↓ 0,065 bajo la media»
public struct RectangularWidgetView: View {
    let content: WidgetContent

    @Environment(\.displayFormat) private var format

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let station = content.cheapest {
                Text(verbatim: [station.name, station.distance].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(format.priceWithCurrency(station.price))
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .widgetAccentable()
                    .opacity(content.staleAge == nil ? 1 : 0.55)
                if let age = content.staleAge {
                    Label { Text(age) } icon: { Image(systemName: "clock") }
                        .font(.caption2.weight(.semibold))
                } else {
                    GapLine(belowAverage: station.belowAverage, colored: false, spacing: 2)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                Text(content.product.displayName).font(.caption.weight(.semibold))
                Text("Sin precios", bundle: .module).font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(content.cheapest?.link)
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Pieces
#endif
