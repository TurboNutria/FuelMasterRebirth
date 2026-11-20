import DesignTokens
import SwiftUI

/// One figure under the chart: a small title over its value, "—" when it isn't known.
struct HistoryStat: View {
    let title: Text
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title.font(.caption).foregroundStyle(ColorTokens.textSecondary)
            Text(value ?? "—")
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
