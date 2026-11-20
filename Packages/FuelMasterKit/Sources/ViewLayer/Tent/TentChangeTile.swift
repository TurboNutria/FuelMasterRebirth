import DomainLayer
import SwiftUI
import ViewModelLayer

/// The small tile at the end of a row: an arrow and the change in cents since yesterday
/// ("▼ −0,8 VS AYER"), or a dash when yesterday isn't known.
struct TentChangeTile: View {
    let change: PriceChange?
    let scale: CGFloat

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(spacing: 4 * scale) {
            if let change {
                Group {
                    switch change.direction {
                    case .down: Image(systemName: "arrowtriangle.down.fill").foregroundStyle(TentColors.down)
                    case .up: Image(systemName: "arrowtriangle.up.fill").foregroundStyle(TentColors.up)
                    case .same: Image(systemName: "minus").foregroundStyle(TentColors.muted)
                    }
                }
                .font(.system(size: 16 * scale, weight: .heavy))
                Text(cents(change))
                    .font(.board(18 * scale, .semibold))
                    .foregroundStyle(TentColors.tileText)
            } else {
                Text(verbatim: "—")
                    .font(.board(18 * scale, .semibold))
                    .foregroundStyle(TentColors.muted)
            }
            Text("vs ayer", bundle: .module)
                .font(.board(12 * scale, .medium))
                .textCase(.uppercase)
                .kerning(1.2 * scale)
                .foregroundStyle(TentColors.muted)
        }
    }

    /// "−0,8": the change in cents, one decimal.
    private func cents(_ change: PriceChange) -> String {
        let value = NSDecimalNumber(decimal: change.difference * 100).doubleValue
        let number = abs(value).formatted(.number.precision(.fractionLength(1)).locale(format.locale))
        switch change.direction {
        case .down: return "−\(number)"
        case .up: return "+\(number)"
        case .same: return number
        }
    }
}
