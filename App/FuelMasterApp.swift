import SwiftUI

@main
struct FuelMasterApp: App {
    @State private var dependencies: AppDependencies?
    @State private var startupError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let dependencies {
                    DataCheckView(dependencies: dependencies)
                } else if let startupError {
                    ContentUnavailableView("No se pudo abrir la base de datos", systemImage: "exclamationmark.triangle",
                                           description: Text(startupError))
                } else {
                    ProgressView()
                }
            }
            .task {
                guard dependencies == nil else { return }
                do {
                    dependencies = try AppDependencies()
                } catch {
                    startupError = error.localizedDescription
                }
            }
        }
    }
}
