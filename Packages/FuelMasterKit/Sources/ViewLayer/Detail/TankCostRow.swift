import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// "Depósito lleno · 55 l   101,20 €": label and amount on one line, stacked when they don't
/// fit, so the amount never breaks.
struct TankCostRow: View {
    let cost: FuelCost

    @Environment(\.displayFormat) private var format
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Picked from the text size rather than ViewThatFits, which kept the one-line layout while
        // the text grew and clipped both (accessibility audit).
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        layout {
            Text("Depósito lleno · \(format.quantity(cost.quantity, unit: cost.unit))", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(format.money(cost.amount))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(ColorTokens.textPrimary)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}
