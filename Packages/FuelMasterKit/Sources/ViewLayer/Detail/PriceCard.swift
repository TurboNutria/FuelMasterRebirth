import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The big price (the screen's one large figure), its gap to the average and the full-tank cost.
struct PriceCard: View {
    let detail: StationDetail
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let price = detail.price {
                VStack(alignment: .leading, spacing: 4) {
                    PriceHeadline(price: price, level: detail.level)
                    // Plain text, no pill.
                    GapLine(belowAverage: detail.belowAverage)
                        .font(.subheadline.weight(.medium))
                }
                if let cost = detail.fuelCost {
                    RowSeparator()
                    TankCostRow(cost: cost)
                }
            } else {
                Text("Esta gasolinera no vende \(String(localized: product.displayName))", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
