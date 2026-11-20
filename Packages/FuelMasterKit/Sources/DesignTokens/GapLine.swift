import SwiftUI
import ViewModelLayer

/// A price against its area's average: "↓ 0,065 bajo la media" in green, "↑ 0,004 sobre la
/// media" in red, "En la media" in grey. Shown under the detail's price, in the widgets and on
/// the watch, each with its own font. Nothing when the average isn't known.
public struct GapLine: View {
    /// Average minus price: positive is below the average.
    let belowAverage: Decimal?
    let colored: Bool
    let spacing: CGFloat

    @Environment(\.displayFormat) private var format

    public init(belowAverage: Decimal?, colored: Bool = true, spacing: CGFloat = 4) {
        self.belowAverage = belowAverage
        self.colored = colored
        self.spacing = spacing
    }

    public var body: some View {
        if let gap = belowAverage {
            let amount = format.price(abs(gap))
            HStack(spacing: spacing) {
                if gap != 0 { Image(systemName: gap > 0 ? "arrow.down" : "arrow.up").imageScale(.small) }
                if gap > 0 {
                    Text("\(amount) bajo la media", bundle: .module)
                } else if gap < 0 {
                    Text("\(amount) sobre la media", bundle: .module)
                } else {
                    Text("En la media", bundle: .module)
                }
            }
            .monospacedDigit()
            .foregroundStyle(colored ? Self.color(gap) : Color.primary)
        }
    }

    private static func color(_ gap: Decimal) -> Color {
        gap > 0 ? ColorTokens.priceDown : gap < 0 ? ColorTokens.priceUp : ColorTokens.textSecondary
    }
}
