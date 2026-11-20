import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Fuel plate, LED price and the change since yesterday.
struct TentPriceRow: View {
    let row: TentBoardRow
    let scale: CGFloat

    @Environment(\.displayFormat) private var format

    var body: some View {
        HStack(spacing: 14 * scale) {
            HStack(spacing: 18 * scale) {
                FuelBadge(product: row.product, scale: scale)
                Text(row.product.displayName)
                    .font(.board(32 * scale, .bold))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(TentColors.ink)
            .padding(.horizontal, 20 * scale)
            .frame(width: 300 * scale, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(TentColors.plate, in: .rect(cornerRadius: 10 * scale))

            LEDWindow(scale: scale) {
                HStack(alignment: .bottom, spacing: 14 * scale) {
                    SevenSegmentText(text: Self.signPrice(row.amount), unit: 10 * scale, color: TentColors.priceLED,
                                     smallLast: true)
                    Text(row.product.unit.pricePerUnit)
                        .font(.board(20 * scale, .semibold))
                        .foregroundStyle(TentColors.muted)
                        .padding(.bottom, 4 * scale)
                }
            }

            TentChangeTile(change: row.change, scale: scale)
                .frame(width: 92 * scale)
                .frame(maxHeight: .infinity)
                .background(TentColors.tile, in: .rect(cornerRadius: 10 * scale))
        }
        .frame(height: 96 * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenText))
    }

    /// "1.459": always a point and three decimals, as signs show them.
    static func signPrice(_ amount: Decimal) -> String {
        String(format: "%.3f", NSDecimalNumber(decimal: amount).doubleValue)
    }

    private var spokenText: String {
        let name = String(localized: row.product.displayName)
        var text = "\(name): \(format.priceWithCurrency(row.amount))"
        if let change = row.change { text += ". " + ChangeLabel(change: change).spokenText }
        return text
    }
}
