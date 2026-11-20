import DesignTokens
import SwiftUI
import ViewModelLayer

/// Mínimo, Máximo and the change over the week, under the chart.
struct HistoryStats: View {
    let chart: HistoryChart

    @Environment(\.displayFormat) private var format

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8) {
            GridRow {
                HistoryStat(title: Text("Mínimo", bundle: .module), value: chart.minimum.map(format.price))
                HistoryStat(title: Text("Máximo", bundle: .module), value: chart.maximum.map(format.price))
                HistoryStat(title: Text("Hoy vs. hace 7 d", bundle: .module), value: changeText)
            }
        }
    }

    /// "+0,010" / "−0,010" in the chips' format, or "Sin cambios".
    private var changeText: String? {
        guard let change = chart.change else { return nil }
        let amount = format.price(abs(change.difference))
        switch change.direction {
        case .up: return "+\(amount)"
        case .down: return "\u{2212}\(amount)"
        case .same: return String(localized: "Sin cambios", bundle: .module)
        }
    }
}
