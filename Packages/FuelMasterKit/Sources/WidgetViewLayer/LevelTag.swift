import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

/// "↓ Barata" / "↑ Cara" in an outline: in tinted and clear widgets colour is gone, so the
/// level needs words. Average prices carry nothing.
struct LevelTag: View {
    let level: PriceLevel

    var body: some View {
        if let text {
            text
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .overlay { Capsule().stroke(lineWidth: 1.5) }
                .widgetAccentable()
        }
    }

    private var text: Text? {
        switch level {
        case .cheap: Text("↓ Barata", bundle: .module)
        case .expensive: Text("↑ Cara", bundle: .module)
        case .average: nil
        }
    }
}
#endif
