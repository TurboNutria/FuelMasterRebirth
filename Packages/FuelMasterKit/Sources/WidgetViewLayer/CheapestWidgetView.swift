import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

public struct CheapestWidgetView: View {
    let content: WidgetContent

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.displayFormat) private var format

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "fuelpump.fill")
                    .foregroundStyle(accent.tint)
                    .widgetAccentable()
                Text(content.product.displayName)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let distance = content.cheapest?.distance { Text(distance).lineLimit(1) }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ColorTokens.textSecondary)

            Spacer(minLength: 6)

            if let station = content.cheapest {
                VStack(alignment: .leading, spacing: 4) {
                    WidgetPrice(station: station, scale: content.priceScale, isStale: content.staleAge != nil,
                                size: 40)
                    if content.staleAge == nil {
                        if renderingMode == .fullColor {
                            GapLine(belowAverage: station.belowAverage, spacing: 2)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else {
                            LevelTag(level: station.level)
                        }
                    }
                }
                Spacer(minLength: 6)
                HStack(spacing: 6) {
                    WidgetLogo(brand: station.brand, size: 20)
                    Text(station.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                if let age = content.staleAge {
                    StaleTag(age: age).padding(.top, 6)
                }
            } else {
                Text("---")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(ColorTokens.textSecondary)
                Spacer(minLength: 6)
                Text("Sin precios", bundle: .module)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { ColorTokens.surface }
        .widgetURL(content.cheapest?.link)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
    }

    private var accent: AccentColors { AccentColors.colors(for: content.accent) }

    /// «Ballenoil. Diésel, 1,859 €, barata. A 1,4 km.» plus the age when it's old.
    private var spokenText: String {
        let product = String(localized: content.product.displayName)
        guard let station = content.cheapest else {
            return "\(product). " + String(localized: "Sin precios", bundle: .module)
        }
        var parts = ["\(station.name). \(product), \(format.priceWithCurrency(station.price)), \(station.level.spokenName)."]
        if let distance = station.distance { parts.append(distance) }
        if let age = content.staleAge { parts.append(age) }
        return parts.joined(separator: " ")
    }
}

// MARK: - Home Screen: medium, the favourites
#endif
