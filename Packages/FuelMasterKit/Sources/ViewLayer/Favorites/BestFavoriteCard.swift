import DesignTokens
import DomainLayer
import SwiftUI

/// "La más barata": the cheapest favourite and its full tank, set straight on the page with the
/// price as the screen's one large figure. At accessibility sizes the price moves under the name.
struct BestFavoriteCard: View {
    let best: BestFavorite

    @Environment(\.displayFormat) private var format
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let label = Text("La más barata", bundle: .module)
            .font(.footnote)
            .foregroundStyle(ColorTokens.textSecondary)
        let name = Text(best.summary.station.name)
            .font(.title3.weight(.semibold))
            .foregroundStyle(ColorTokens.textPrimary)
        let cost = best.fuelCost.map { cost in
            Text("Depósito lleno (\(format.quantity(cost.quantity, unit: cost.unit))): \(format.money(cost.amount))",
                 bundle: .module)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.textSecondary)
        }
        let price = HeroPrice(amount: best.summary.price.amount, level: best.summary.level)
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    label
                    name
                    price
                    if let cost { cost }
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        label
                        name
                        if let cost { cost }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    price
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
