import SwiftUI
import ViewModelLayer

/// Closes the detail when it isn't pushed (sheet, pane, inspector).
struct CloseDetailButton: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button(action: close) {
            Label { Text("Cerrar", bundle: .module) } icon: { Image(systemName: "xmark") }
        }
    }

    private func close() {
        router.select(nil)
    }
}
