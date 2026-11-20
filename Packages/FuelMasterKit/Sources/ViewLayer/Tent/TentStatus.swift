import SwiftUI
import ViewModelLayer

/// "● ABIERTA 24 H" in green or "● CERRADA" in orange; nothing when the hours can't be read.
struct TentStatus: View {
    let content: TentBoardContent
    let scale: CGFloat

    var body: some View {
        if let label {
            let color = content.isClosed ? TentColors.closed : TentColors.open
            HStack(spacing: 8 * scale) {
                Circle().fill(color).frame(width: 10 * scale, height: 10 * scale)
                label.textCase(.uppercase)
            }
            .foregroundStyle(color)
        }
    }

    private var label: Text? {
        switch content.detail.openingStatus {
        case .alwaysOpen: Text("Abierta 24 h", bundle: .module)
        case .open: content.hours.today == .allDay ? Text("Abierta 24 h", bundle: .module) : Text("Abierta", bundle: .module)
        case .closed: Text("Cerrada", bundle: .module)
        case .unknown: nil
        }
    }
}
