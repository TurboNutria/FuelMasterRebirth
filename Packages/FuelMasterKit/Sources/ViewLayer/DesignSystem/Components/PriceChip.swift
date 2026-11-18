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
    let brand: Brand?

    @Environment(\.priceScale) private var scale
    @Environment(\.displayFormat) private var format
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    /// A nil amount is the grey "---" placeholder shown on first load. A brand puts its logo
    /// at the front of the capsule (map pins).
    public init(amount: Decimal?, level: PriceLevel?, size: Size = .regular, brand: Brand? = nil) {
        self.amount = amount
        self.level = level
        self.size = size
        self.brand = brand
    }

    public var body: some View {
        HStack(spacing: 2) {
            if let brand {
                BrandLogo(brand: brand, size: Self.logoSize).padding(.trailing, 2)
            }
            if differentiateWithoutColor, let arrow {
                Image(systemName: arrow).font(.caption.weight(.heavy))
            }
            Text(amount.map(format.price) ?? "---")
                .font(size == .regular ? .price : .system(.footnote, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(colors?.foreground ?? ColorTokens.textSecondary)
        .padding(.vertical, brand == nil ? 4 : 3)
        .padding(.horizontal, size == .regular ? 10 : 8)
        .padding(.leading, brand == nil ? 0 : -5)
        .background(colors?.background ?? ColorTokens.cell, in: .capsule)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// Fills the small chip's height, inside a thin rim of the price colour.
    private static let logoSize: CGFloat = 18

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
