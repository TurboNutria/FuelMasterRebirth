import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

/// The big price: the cheap colour of the user's scale, plain ink otherwise (as on the detail),
/// dimmed when the prices are over an hour old.
struct WidgetPrice: View {
    let station: WidgetStation
    let scale: PriceScale
    let isStale: Bool
    let size: CGFloat

    @Environment(\.displayFormat) private var format
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Text(format.price(station.price))
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(color)
            .widgetAccentable()
            .opacity(isStale ? 0.55 : 1)
    }

    private var color: Color {
        guard renderingMode == .fullColor, station.level == .cheap else { return ColorTokens.textPrimary }
        return PriceLevelColors.colors(for: .cheap, scale: scale).background
    }
}
#endif
