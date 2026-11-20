import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

struct FailedListView: View {
    let error: DomainError
    let onRetry: () -> Void

    var body: some View {
        EmptyStateView(
            systemImage: error == .offline ? "wifi.slash" : "exclamationmark.icloud",
            title: error == .offline
                ? String(localized: "Sin conexión", bundle: .module)
                : String(localized: "No se pudieron cargar los precios", bundle: .module),
            message: error == .offline
                ? String(localized: "Conéctate a internet para ver los precios de hoy.", bundle: .module)
                : String(localized: "El servidor del ministerio no responde. Inténtalo de nuevo en unos minutos.", bundle: .module),
            actionTitle: String(localized: "Reintentar", bundle: .module),
            action: onRetry
        )
    }
}
