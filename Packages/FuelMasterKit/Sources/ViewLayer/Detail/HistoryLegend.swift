import DesignTokens
import SwiftUI

/// The chart's key: "Esta estación" in the accent, "Media de Madrid" dashed. Hidden from VoiceOver,
/// which reads the chart's own summary.
struct HistoryLegend: View {
    let provinceName: String

    @Environment(\.accentColors) private var accent

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Capsule().fill(accent.tint).frame(width: 16, height: 3)
                Text("Esta estación", bundle: .module)
            }
            HStack(spacing: 8) {
                LegendLine().stroke(ColorTokens.closed, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).frame(width: 16, height: 2)
                Text("Media de \(provinceName)", bundle: .module)
            }
        }
        .font(.caption)
        .foregroundStyle(ColorTokens.textSecondary)
        .accessibilityHidden(true)
    }
}
