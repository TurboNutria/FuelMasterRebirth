import SwiftUI

/// Grey icon, title, message and an optional glass action: "No hay gasolineras con GNL cerca",
/// "Aún no tienes favoritas", "Sin resultados para «28999»".
public struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(systemImage: String, title: String, message: String,
                actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(ColorTokens.closed)
            }
        } description: {
            Text(message)
                .foregroundStyle(ColorTokens.textSecondary)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.accentGlass)
            }
        }
    }
}

#Preview("Empty state") {
    EmptyStateView(
        systemImage: "fuelpump.slash",
        title: "No hay gasolineras con GNL cerca",
        message: "La más cercana está a 7,4 km. Mueve el mapa para ver otra zona o cambia de combustible.",
        actionTitle: "Ver en el mapa"
    ) {}
    .background(ColorTokens.background)
}
