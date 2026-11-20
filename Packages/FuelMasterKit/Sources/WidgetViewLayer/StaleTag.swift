import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer

/// "Hace 3 h" in red: the prices haven't been updated for over an hour.
struct StaleTag: View {
    let age: String

    var body: some View {
        Label { Text(age) } icon: { Image(systemName: "clock") }
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(ColorTokens.offline, in: .capsule)
            .fixedSize()
    }
}
#endif
