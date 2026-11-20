import DesignTokens
import SwiftUI
import ViewModelLayer

/// The sign itself, at `scale` × the design's sizes.
struct TentBoard: View {
    /// The canvas's board; everything on it is sized for this and scaled to fit the screen.
    static let designSize = CGSize(width: 880, height: 440)

    let content: TentBoardContent
    let caption: Text?
    let distance: Double?
    let nearestOpen: Double?
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 10 * scale) {
            TentHeader(content: content, caption: caption, distance: distance, scale: scale)
            if content.isClosed {
                TentClosedPanel(reopening: content.reopening, nearestOpen: nearestOpen, scale: scale)
            } else {
                ForEach(content.rows) { row in
                    TentPriceRow(row: row, scale: scale)
                }
            }
            Spacer(minLength: 0)
            TentFooter(pricesDate: content.detail.freshness?.snapshotDate, scale: scale)
        }
        .padding(18 * scale)
        .frame(width: Self.designSize.width * scale, height: Self.designSize.height * scale)
        .background(TentColors.background, in: .rect(cornerRadius: 28 * scale))
        .foregroundStyle(TentColors.text)
    }
}
