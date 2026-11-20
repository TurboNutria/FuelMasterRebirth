import DesignTokens
import SwiftUI

/// A tab's large title ("Gasolineras", "Favoritos"): heavy, rounded, shrinking rather than
/// wrapping, and a header for VoiceOver.
struct ScreenTitle: View {
    let text: Text

    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        text
            .font(.screenTitle)
            .foregroundStyle(ColorTokens.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityAddTraits(.isHeader)
    }
}
