import DesignTokens
import DomainLayer
import SwiftUI

/// A screen's one large price: 44 pt at the default text size and growing with Dynamic Type,
/// in the cheap colour when it's cheap for the area and plain ink otherwise (Monochrome's cheap
/// fill is ink anyway). Shrinks rather than wrapping.
struct HeroPrice: View {
    let amount: Decimal
    let level: PriceLevel?

    @Environment(\.displayFormat) private var format
    @Environment(\.priceScale) private var scale
    @ScaledMetric(relativeTo: .largeTitle) private var size = Metrics.heroPrice

    var body: some View {
        Text(format.price(amount))
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(level == .cheap ? PriceLevelColors.colors(for: .cheap, scale: scale).background
                                             : ColorTokens.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}
