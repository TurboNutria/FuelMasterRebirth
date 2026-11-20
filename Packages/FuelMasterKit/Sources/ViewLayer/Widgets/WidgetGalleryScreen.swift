import DesignTokens
#if os(iOS) && DEBUG
import SwiftUI
import ViewModelLayer
import WidgetViewLayer

/// DEBUG: `-FMWidgetGallery YES` draws every widget at its iPhone size from the live cache, for
/// screenshots without adding widgets to the simulator's Home Screen.
public struct WidgetGalleryScreen: View {
    let content: WidgetContent
    let stale: WidgetContent

    public init(content: WidgetContent, stale: WidgetContent) {
        self.content = content
        self.stale = stale
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 20) {
                    frame(CheapestWidgetView(content: content), width: 170, height: 170)
                    frame(CheapestWidgetView(content: stale), width: 170, height: 170)
                }
                frame(FavoritesWidgetView(content: content), width: 364, height: 170)
                HStack(spacing: 20) {
                    lockFrame(CircularWidgetView(content: content), width: 72, height: 72, circle: true)
                    lockFrame(RectangularWidgetView(content: content), width: 170, height: 72, circle: false)
                }
                InlineWidgetView(content: content).foregroundStyle(.white)
            }
            .padding(20)
        }
        .background(LinearGradient(colors: [Color(red: 0.52, green: 0.76, blue: 0.89), Color(red: 0.96, green: 0.85, blue: 0.75)],
                                   startPoint: .top, endPoint: .bottom))
    }

    private func frame(_ view: some View, width: CGFloat, height: CGFloat) -> some View {
        view.padding(16)
            .frame(width: width, height: height)
            .background(ColorTokens.surface, in: .rect(cornerRadius: 24))
    }

    private func lockFrame(_ view: some View, width: CGFloat, height: CGFloat, circle: Bool) -> some View {
        view.frame(width: width, height: height)
            .foregroundStyle(.white)
            .background(.black.opacity(0.25), in: .rect(cornerRadius: circle ? width / 2 : 16))
    }
}
#endif
