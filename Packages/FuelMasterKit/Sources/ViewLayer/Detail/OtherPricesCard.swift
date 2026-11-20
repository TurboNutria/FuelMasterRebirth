import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The station's other products ("Diésel Premium 1,879"), as rows with hairlines.
struct OtherPricesCard: View {
    let prices: [Price]

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(spacing: 0) {
            RowSeparator()
            ForEach(prices, id: \.product) { price in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(price.product.displayName)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer(minLength: 8)
                    Text(format.price(price.amount))
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.textPrimary)
                    if price.unit == .kilogram {
                        Text(price.unit.pricePerUnit).foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .font(.subheadline)
                .frame(minHeight: 48)
                .accessibilityElement(children: .combine)
                RowSeparator()
            }
        }
    }
}
