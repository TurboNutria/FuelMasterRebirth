import DesignTokens
import SwiftUI

/// "Actualizando…" and the red offline pill, stacked at the bottom of Gasolineras and Mapa.
struct StatusPillStack: View {
    let isUpdating: Bool
    let showsOffline: Bool
    /// When the prices on screen were published, for "precios de hace 2 h".
    let pricesDate: Date?
    let onDismissOffline: () -> Void

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(spacing: 10) {
            if isUpdating { UpdatingPill() }
            if showsOffline {
                OfflinePill(age: pricesDate.map { format.relativeTimeInSentence($0, now: .now) },
                            onDismiss: onDismissOffline)
            }
        }
        .padding(.bottom, 12)
    }
}
