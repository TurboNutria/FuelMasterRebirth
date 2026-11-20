import DomainLayer
import SwiftUI
import ViewModelLayer

/// Today against yesterday, in the chip's own number format: an arrow and "0,020" in green when
/// it went down, red when it went up. Rows hide it when the price is the same.
public struct ChangeLabel: View {
    let change: PriceChange

    @Environment(\.displayFormat) private var format

    public init(change: PriceChange) {
        self.change = change
    }

    public var body: some View {
        HStack(spacing: 2) {
            if let arrow { Image(systemName: arrow).imageScale(.small) }
            Text(format.price(abs(change.difference))).monospacedDigit()
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
    }

    private var arrow: String? {
        switch change.direction {
        case .down: "arrow.down"
        case .up: "arrow.up"
        case .same: "equal"
        }
    }

    private var color: Color {
        switch change.direction {
        case .down: ColorTokens.priceDown
        case .up: ColorTokens.priceUp
        case .same: ColorTokens.textSecondary
        }
    }

    public var spokenText: String {
        let amount = format.priceWithCurrency(abs(change.difference))
        switch change.direction {
        case .down: return String(localized: "Ha bajado \(amount) desde ayer", bundle: .module)
        case .up: return String(localized: "Ha subido \(amount) desde ayer", bundle: .module)
        case .same: return String(localized: "Igual que ayer", bundle: .module)
        }
    }
}
