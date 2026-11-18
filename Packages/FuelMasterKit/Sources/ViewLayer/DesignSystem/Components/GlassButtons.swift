import SwiftUI

/// Liquid Glass capsule tinted with the accent: the fuel picker ("Diésel ⌄"), "Ver en el mapa",
/// "Cómo llegar". Reduce Transparency is handled by the system glass.
public struct AccentGlassButtonStyle: PrimitiveButtonStyle {
    @Environment(\.accentColors) private var accent

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(.body.weight(.semibold))
                .foregroundStyle(accent.tint)
        }
        .buttonStyle(.glass)
        .tint(accent.fill.opacity(0.22))
        .controlSize(.large)
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
    }
}

/// The same accent glass capsule for a `Menu` label (menus don't take primitive button styles).
struct AccentGlassMenu: ViewModifier {
    @Environment(\.accentColors) private var accent

    func body(content: Content) -> some View {
        content
            .font(.body.weight(.semibold))
            .foregroundStyle(accent.tint)
            .menuStyle(.button)
            .buttonStyle(.glass)
            .tint(accent.fill.opacity(0.22))
            .controlSize(.large)
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
    func accentGlassMenu() -> some View { modifier(AccentGlassMenu()) }
    func plainAccentMenu() -> some View { modifier(PlainAccentMenu()) }
}

extension PrimitiveButtonStyle where Self == AccentGlassButtonStyle {
    public static var accentGlass: AccentGlassButtonStyle { AccentGlassButtonStyle() }
}

#Preview("Glass buttons") {
    VStack(spacing: 16) {
        Button {} label: {
            Label { Text(verbatim: "Diésel") } icon: { Image(systemName: "chevron.down") }
                .labelStyle(.trailingIcon)
        }
        .buttonStyle(.accentGlass)
        Button(String(localized: "Ver en el mapa", bundle: .module)) {}
            .buttonStyle(.accentGlass)
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
