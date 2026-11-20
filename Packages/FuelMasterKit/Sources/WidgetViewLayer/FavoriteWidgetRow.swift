import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

struct FavoriteWidgetRow: View {
    let station: WidgetStation
    let isStale: Bool
    let accented: Bool

    @Environment(\.displayFormat) private var format

    var body: some View {
        HStack(spacing: 8) {
            WidgetLogo(brand: station.brand, size: 22)
            HStack(spacing: 4) {
                Text(station.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                if let distance = station.distance {
                    Text(verbatim: "· \(distance)")
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .layoutPriority(1)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            if accented {
                if station.level != .average { LevelTag(level: station.level) }
                Text(format.price(station.price))
                    .font(.system(.callout, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .widgetAccentable()
            } else {
                if let change = station.change, change.direction != .same { ChangeLabel(change: change) }
                PriceChip(amount: station.price, level: station.level)
            }
        }
        .opacity(isStale ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(station.name), \(format.priceWithCurrency(station.price)), \(station.level.spokenName)"))
    }
}

// MARK: - Lock Screen
#endif
