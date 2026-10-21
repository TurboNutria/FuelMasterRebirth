import DomainLayer
import SwiftUI
import ViewModelLayer

/// The coloured price capsule ("1,859") used in rows, cards and pins.
/// Colours come from the user's price scale. With Differentiate Without Colour, cheap and
/// expensive prices also carry ↓ / ↑ (canvas: Accesibilidad).
public struct PriceChip: View {
    public enum Size: Sendable {
        /// Rows and cards (16 pt).
        case regular
        /// Map pins (13 pt).
        case small
    }

    let amount: Decimal?
    let level: PriceLevel?
    let size: Size

    @Environment(\.priceScale) private var scale
    @Environment(\.displayFormat) private var format
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    /// A nil amount is the grey "---" placeholder shown on first load.
    public init(amount: Decimal?, level: PriceLevel?, size: Size = .regular) {
        self.amount = amount
        self.level = level
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 3) {
            if differentiateWithoutColor, let arrow {
                Image(systemName: arrow).font(.caption.weight(.heavy))
            }
            Text(amount.map(format.price) ?? "---")
                .font(size == .regular ? .price : .system(.footnote, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(colors?.foreground ?? ColorTokens.textSecondary)
        .padding(.vertical, 3)
        .padding(.horizontal, size == .regular ? 9 : 8)
        .background(colors?.background ?? ColorTokens.cell, in: .capsule)
        .overlay {
            if let border = colors?.border { Capsule().strokeBorder(border, lineWidth: 1) }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var colors: PriceLevelColors? {
        level.map { PriceLevelColors.colors(for: $0, scale: scale) }
    }

    private var arrow: String? {
        switch level {
        case .cheap: "arrow.down"
        case .expensive: "arrow.up"
        case .average, nil: nil
        }
    }

    private var accessibilityText: Text {
        guard let amount else { return Text("Precio cargando", bundle: .module) }
        let price = format.priceWithCurrency(amount)
        guard let level else { return Text(price) }
        return Text("\(price), \(level.spokenName)", bundle: .module, comment: "Price and its level: 1,859 €, barata")
    }
}

#Preview("Price chips") {
    VStack(spacing: 12) {
        ForEach(PriceScale.allCases, id: \.self) { scale in
            HStack {
                PriceChip(amount: 1.859, level: .cheap)
                PriceChip(amount: 1.879, level: .average)
                PriceChip(amount: 1.969, level: .expensive)
                PriceChip(amount: nil, level: nil)
            }
            .environment(\.priceScale, scale)
        }
    }
    .padding()
}
