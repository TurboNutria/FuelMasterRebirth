import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Fuente y aviso legal (canvas: "Fuente y aviso legal"): the source and its licence, the newest
/// data date, the disclaimer and privacy, each in a sentence or two.
struct LegalScreen: View {
    let viewModel: SettingsViewModel

    @Environment(\.displayFormat) private var format
    @Environment(\.accentColors) private var accent

    var body: some View {
        SettingsList {
            SettingsSection(Text("Datos", bundle: .module), spacingAbove: 8) {
                Text("Ministerio para la Transición Ecológica y el Reto Demográfico. Licencia CC BY 4.0.", bundle: .module)
                if let date = viewModel.dataSource?.snapshotDate {
                    LabeledContent {
                        // «17 nov 2026, 14:45»: the month in words, so the day and month can't be swapped.
                        Text(date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(format.locale)))
                    } label: {
                        Text("Datos del", bundle: .module)
                    }
                }
                Link(destination: URL(string: "https://geoportalgasolineras.es")!) {
                    Text("Ver la fuente", bundle: .module)
                }
                // A plain list doesn't tint links, so give it the accent as Gasolineras' menus have.
                .foregroundStyle(accent.tint)
            }
            SettingsSection(Text("Aviso", bundle: .module)) {
                Text("FuelMaster no está vinculada al Ministerio ni a ninguna marca. Comprueba el precio en el surtidor.", bundle: .module)
            }
            SettingsSection(Text("Privacidad", bundle: .module)) {
                Text("Tu ubicación solo se usa en tu dispositivo. Sin cuentas, anuncios ni rastreo.", bundle: .module)
            }
            Text(verbatim: "FuelMaster \(Self.version)")
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.top, 32)
                .padding(.bottom, 24)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .font(.subheadline)
        .navigationTitle(Text("Fuente y aviso legal", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.loadDataSource() }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
