import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The black LED window with an inner shadow.
struct LEDWindow<Content: View>: View {
    let scale: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 22 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .background(TentColors.window, in: .rect(cornerRadius: 10 * scale))
            .overlay {
                RoundedRectangle(cornerRadius: 10 * scale).strokeBorder(TentColors.windowBorder, lineWidth: 2 * scale)
            }
    }
}
