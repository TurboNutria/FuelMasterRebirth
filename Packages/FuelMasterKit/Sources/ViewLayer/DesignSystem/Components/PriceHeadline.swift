import DesignTokens
import DomainLayer
import SwiftUI

/// The fuel's name over its large price, with the unit beside it: the detail and the peek.
struct PriceHeadline: View {
    let price: Price
    let level: PriceLevel?

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(price.product.displayName)
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                HeroPrice(amount: price.amount, level: level)
                Text(price.unit.pricePerUnit)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenText))
    }

    /// «Diésel, 1,859 €, barata».
    private var spokenText: String {
        [String(localized: price.product.displayName), format.priceWithCurrency(price.amount), level?.spokenName]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
