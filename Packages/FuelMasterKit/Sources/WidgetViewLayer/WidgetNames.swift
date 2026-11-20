import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

// The widgets (canvas: "Widgets · pantalla de inicio" and "transparente, tintado y bloqueo").
// The extension only supplies timelines; everything drawn lives here, in its own target so the
// extension links the design system and nothing else of the app's interface.

/// Names in the widget gallery.
public enum WidgetNames {
    public static let cheapest = LocalizedStringResource("Más barata cerca", bundle: .widgetViewLayer)
    public static let favorites = LocalizedStringResource("Favoritos", bundle: .widgetViewLayer)
}

// MARK: - Home Screen: small, the cheapest nearby
#endif
