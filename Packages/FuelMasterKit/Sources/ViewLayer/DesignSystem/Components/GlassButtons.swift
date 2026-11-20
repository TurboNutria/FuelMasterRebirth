import DesignTokens
import SwiftUI

/// Tinted text for an action on the page (an empty state's "Ver todas"), at least 44 pt tall.
/// Glass is for controls floating over the map.
public struct PlainAccentButtonStyle: ButtonStyle {
    @Environment(\.accentColors) private var accent

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(accent.tint)
            .frame(minHeight: 44)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

/// Round glass icon button for map controls ("Centrar en mi ubicación", Compartir).
/// The label is required: these buttons have no visible text.
public struct GlassIconButton: View {
    let systemImage: String
    let label: Text
    let action: () -> Void

    @Environment(\.accentColors) private var accent

    public init(systemImage: String, label: Text, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent.tint)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        // About 44 pt overall, the height of the glass menus beside it (it was 56).
        .controlSize(.large)
        .accessibilityLabel(label)
        .accessibilityShowsLargeContentViewer {
            Image(systemName: systemImage)
            label
        }
    }
}

/// A menu that sits on the page, not over content: tinted text, no capsule.
struct PlainAccentMenu: ViewModifier {
    @Environment(\.accentColors) private var accent

    func body(content: Content) -> some View {
        content
            .font(.body.weight(.semibold))
            .foregroundStyle(accent.tint)
            .menuStyle(.button)
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .contentShape(.rect)
    }
}

extension View {
    func plainAccentMenu() -> some View { modifier(PlainAccentMenu()) }
}

extension ButtonStyle where Self == PlainAccentButtonStyle {
    public static var plainAccent: PlainAccentButtonStyle { PlainAccentButtonStyle() }
}

#Preview("Glass buttons") {
    VStack(spacing: 16) {
        Button {} label: {
            Label { Text(verbatim: "Diésel") } icon: { Image(systemName: "chevron.down") }
                .labelStyle(.trailingIcon)
        }
        .buttonStyle(.plainAccent)
        Button(String(localized: "Ver en el mapa", bundle: .module)) {}
            .buttonStyle(.plainAccent)
        GlassIconButton(systemImage: "location.fill", label: Text("Centrar en mi ubicación", bundle: .module)) {}
    }
    .padding(40)
    .background(ColorTokens.background)
}

/// "Diésel ⌄": text first, icon after.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}
