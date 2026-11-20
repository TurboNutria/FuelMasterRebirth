import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

/// The chain's logo, or the grey pump. Kept in its own colours in tinted widgets, where a
/// tinted white disc would turn into a blank circle.
struct WidgetLogo: View {
    let brand: Brand?
    let size: CGFloat

    var body: some View {
        if let brand {
            Image(brand: brand)
                .resizable()
                .interpolation(.high)
                .widgetAccentedRenderingMode(.desaturated)
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(.circle)
                .accessibilityHidden(true)
        } else {
            StationLogo(brand: nil, size: size)
        }
    }
}
#endif
