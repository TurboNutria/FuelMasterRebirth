import SwiftUI
import ViewModelLayer

/// "Actualizado 17:28 · Precios del Ministerio" and the app's name, along the bottom.
struct TentFooter: View {
    let pricesDate: Date?
    let scale: CGFloat

    @Environment(\.displayFormat) private var format

    var body: some View {
        HStack {
            if let pricesDate {
                Text("Actualizado \(format.time(pricesDate)) · Precios del Ministerio", bundle: .module)
            }
            Spacer()
            Text(verbatim: "FuelMaster")
        }
        .font(.board(15 * scale, .medium))
        .foregroundStyle(TentColors.muted)
        .padding(.horizontal, 6 * scale)
        .frame(height: 20 * scale)
    }
}
