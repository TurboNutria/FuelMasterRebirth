import SwiftUI

/// "Actualizando…" while new prices load over the cache. Never announced: it would be noise
/// every 30 minutes (canvas: Accesibilidad).
public struct UpdatingPill: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Actualizando…", bundle: .module)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(ColorTokens.textSecondary)
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Red "Sin conexión · precios de hace 2 h" with a close button. Announced once when it appears;
/// the view model remembers a dismissal until the connection comes back.
public struct OfflinePill: View {
    /// "hace 2 h", from `DisplayFormat.relativeTimeInSentence`. Nil when nothing is cached.
    let age: String?
    let onDismiss: () -> Void

    public init(age: String?, onDismiss: @escaping () -> Void) {
        self.age = age
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline.weight(.semibold))
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.heavy))
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(0.22), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Cerrar aviso", bundle: .module))
        }
        .foregroundStyle(.white)
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 36)
        .background(ColorTokens.offline, in: .capsule)
        .shadow(color: ColorTokens.offline.opacity(0.35), radius: 8, y: 6)
        .accessibilityElement(children: .contain)
        .onAppear {
            AccessibilityNotification.Announcement(message).post()
        }
    }

    private var message: String {
        guard let age else { return String(localized: "Sin conexión", bundle: .module) }
        return String(localized: "Sin conexión · precios de \(age)", bundle: .module,
                      comment: "Offline pill; the argument reads like “hace 2 h”")
    }
}

#Preview("Pills") {
    VStack(spacing: 20) {
        UpdatingPill()
        OfflinePill(age: "hace 2 h") {}
    }
    .padding(40)
    .background(ColorTokens.background)
}
