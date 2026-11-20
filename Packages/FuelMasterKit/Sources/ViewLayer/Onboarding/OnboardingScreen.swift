import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Onboarding (canvas: "Bienvenida", "Combustible", "Ubicación"): three short screens, then a
/// province list when location isn't shared. Shown instead of the app until it's done, so the
/// app doesn't ask for location before "Usar mi ubicación".
public struct OnboardingScreen: View {
    let viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .welcome: WelcomeStep(onNext: viewModel.next)
                case .fuel: FuelStep(viewModel: viewModel)
                case .location: LocationStep(viewModel: viewModel)
                case .province:
                    ProvincePicker(provinces: viewModel.provinces, selection: nil) { id in
                        Task { await viewModel.choose(id) }
                    }
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.background)
            .toolbar {
                if viewModel.step != .welcome {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: viewModel.back) {
                            Label { Text("Atrás", bundle: .module) } icon: { Image(systemName: "chevron.left") }
                        }
                    }
                }
            }
            .animation(.default, value: viewModel.step)
        }
    }
}

/// A step's page: the content, then the buttons at the bottom, scrolling as one when the text
/// is too large to fit (accessibility audit: the fixed page clipped its text).
struct OnboardingPage<Content: View, Buttons: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let buttons: Buttons

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    Spacer(minLength: 0)
                    content
                    Spacer(minLength: 0)
                    VStack(spacing: 8) { buttons }
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// A step's title and the one line under it.
struct OnboardingHeading: View {
    let title: Text
    let subtitle: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            title
                .font(.screenTitle)
                .foregroundStyle(ColorTokens.textPrimary)
                .accessibilityAddTraits(.isHeader)
            subtitle
                .font(.title3)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The accent button at the bottom of each step.
struct OnboardingButton: View {
    let title: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) { title }
            .buttonStyle(OnboardingButtonStyle())
    }
}

/// A flat accent capsule. Not `.borderedProminent`: on iOS 26 that adds a glass rim and a
/// shadow, and this button sits on the page rather than over the map.
struct OnboardingButtonStyle: ButtonStyle {
    @Environment(\.accentColors) private var accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(accent.onFill)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(accent.fill, in: .capsule)
            .contentShape(.capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct WelcomeStep: View {
    let onNext: () -> Void

    /// The icon column, wide enough for the symbols at every text size.
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                WelcomePins()
                OnboardingHeading(title: Text(verbatim: "FuelMaster"),
                                  subtitle: Text("La gasolinera más barata cerca de ti", bundle: .module))
                VStack(alignment: .leading, spacing: 16) {
                    point("checkmark.seal", Text("Precios oficiales", bundle: .module))
                    point("wifi.slash", Text("Funciona sin conexión", bundle: .module))
                    point("hand.raised", Text("Sin cuentas ni anuncios", bundle: .module))
                }
            }
        } buttons: {
            OnboardingButton(title: Text("Empezar", bundle: .module), action: onNext)
        }
    }

    private func point(_ symbol: String, _ title: Text) -> some View {
        Label {
            title
                .foregroundStyle(ColorTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: iconWidth)
        }
    }
}

/// Three of the map's own pins, in the price scale from Ajustes: what the app shows, before it
/// shows it. The cheap one is the large pin, as on the map when a station is open.
struct WelcomePins: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The pins at map size, before they're enlarged.
    @State private var size: CGSize = .zero

    /// Map size is small for the one picture on the page, so it's drawn larger (text stays sharp),
    /// except at accessibility sizes, where the text already makes it large.
    private var scale: CGFloat { typeSize.isAccessibilitySize ? 1 : 1.5 }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !typeSize.isAccessibilitySize {
                chip("1.459", .average).padding(.top, 28)
            }
            HighlightedPin(amount: Decimal(string: "1.389")!, level: .cheap)
            if !typeSize.isAccessibilitySize {
                chip("1.529", .expensive).padding(.top, 8)
            }
        }
        .fixedSize()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func chip(_ amount: String, _ level: PriceLevel) -> some View {
        PriceChip(amount: Decimal(string: amount)!, level: level, size: .small)
            .shadow(color: .black.opacity(0.14), radius: 3, y: 2)
    }
}

struct FuelStep: View {
    @Bindable var viewModel: OnboardingViewModel

    @Environment(\.accentColors) private var accent

    var body: some View {
        VStack(spacing: 0) {
            SettingsList {
                Text("¿Qué combustible usas?", bundle: .module)
                    .font(.screenTitle)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                SettingsSection(nil, spacingAbove: 16) {
                    ForEach(Product.allCases) { product in
                        Button {
                            viewModel.product = product
                        } label: {
                            HStack {
                                Text(product.displayName).foregroundStyle(ColorTokens.textPrimary)
                                Spacer()
                                if product == viewModel.product {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(accent.tint)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .accessibilityAddTraits(product == viewModel.product ? .isSelected : [])
                    }
                }
            }
            // Pinned under the list, so it isn't missed below twelve fuels.
            VStack(spacing: 0) {
                RowSeparator()
                TankSizeRow(size: viewModel.tankSize, unit: viewModel.product.unit) { viewModel.setTankSize($0) }
                    .frame(minHeight: 32)
                    .padding(.vertical, 12)
                OnboardingButton(title: Text("Siguiente", bundle: .module), action: viewModel.next)
                    .padding(.top, 12)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 16)
        }
    }
}

struct LocationStep: View {
    let viewModel: OnboardingViewModel

    @Environment(\.accentColors) private var accent

    var body: some View {
        OnboardingPage {
            OnboardingHeading(title: Text("¿Dónde buscamos?", bundle: .module),
                              subtitle: Text("Tu ubicación solo se usa en tu iPhone", bundle: .module))
        } buttons: {
            OnboardingButton(title: Text("Usar mi ubicación", bundle: .module)) {
                Task { await viewModel.useLocation() }
            }
            Button {
                Task { await viewModel.chooseProvinceByHand() }
            } label: {
                Text("Elegir provincia", bundle: .module)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent.tint)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}
