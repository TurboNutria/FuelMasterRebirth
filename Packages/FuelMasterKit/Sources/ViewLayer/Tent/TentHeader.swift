import DesignTokens
import SwiftUI
import ViewModelLayer

/// The board's top line: the "FM" plate, the caption over the station's name, then the distance
/// and whether it's open.
struct TentHeader: View {
    let content: TentBoardContent
    let caption: Text?
    let distance: Double?
    let scale: CGFloat

    @Environment(\.displayFormat) private var format

    var body: some View {
        HStack(spacing: 12 * scale) {
            Text(verbatim: "FM")
                .font(.board(18 * scale, .bold))
                .foregroundStyle(TentColors.ink)
                .frame(width: 36 * scale, height: 36 * scale)
                .background(TentColors.plate, in: .rect(cornerRadius: 8 * scale))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                if let caption {
                    caption
                        .font(.board(13 * scale, .semibold))
                        .textCase(.uppercase)
                        .kerning(1.8 * scale)
                        .foregroundStyle(TentColors.muted)
                }
                Text(content.station.name)
                    .font(.board(22 * scale, .semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 8 * scale)
            HStack(spacing: 18 * scale) {
                if let distance { Text(format.distance(meters: distance)) }
                TentStatus(content: content, scale: scale)
            }
            .font(.board(20 * scale, .semibold))
        }
        .padding(.horizontal, 6 * scale)
        .frame(height: 40 * scale)
        .accessibilityElement(children: .combine)
    }
}
