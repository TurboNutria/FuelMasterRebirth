import DesignTokens
import DomainLayer
import SwiftUI

/// "Cómo llegar": opens Apple Maps with directions to the station.
struct DirectionsButton: View {
    let station: Station

    @Environment(\.accentColors) private var accent

    var body: some View {
        Button(action: station.openDirections) {
            // A plain stack: the bottom bar shows a Label as its icon alone.
            HStack(spacing: 8) {
                Image(systemName: "location.north.fill")
                Text("Cómo llegar", bundle: .module)
                    .accessibilityIdentifier("directions")
            }
                .font(.body.weight(.semibold))
                .foregroundStyle(accent.onFill)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.glassProminent)
        .tint(accent.fill)
        // The bottom bar caps its text size; holding the button shows it large instead.
        .accessibilityShowsLargeContentViewer()
    }
}
