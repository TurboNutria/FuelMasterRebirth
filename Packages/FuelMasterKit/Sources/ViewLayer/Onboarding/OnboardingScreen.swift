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

/// The big accent button at the bottom of each step.
struct OnboardingButton: View {
    let title: Text
    let action: () -> Void

    @Environment(\.accentColors) private var accent

    var body: some View {
        Button(action: action) {
            title
                .font(.body.weight(.semibold))
                .foregroundStyle(accent.onFill)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.glassProminent)
        .tint(accent.fill)
        .controlSize(.large)
    }
}

struct WelcomeStep: View {
    let onNext: () -> Void

    @Environment(\.accentColors) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 56))
                .foregroundStyle(accent.fill)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "FuelMaster")
                    .font(.screenTitle)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("La gasolinera más barata cerca de ti.", bundle: .module)
                    .font(.title3)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            VStack(alignment: .leading, spacing: 14) {
                point("checkmark.seal", Text("Precios oficiales", bundle: .module))
                point("wifi.slash", Text("Funciona sin conexión", bundle: .module))
                point("hand.raised", Text("Sin cuentas ni anuncios", bundle: .module))
            }
            Spacer()
            OnboardingButton(title: Text("Empezar", bundle: .module), action: onNext)
        }
        .padding(24)
    }

    private func point(_ symbol: String, _ title: Text) -> some View {
        Label {
            title.font(.headline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(accent.tint).frame(width: 28)
        }
        .foregroundStyle(ColorTokens.textPrimary)
    }
}

struct FuelStep: View {
    @Bindable var viewModel: OnboardingViewModel

    @Environment(\.accentColors) private var accent

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(Product.allCases) { product in
                        Button {
                            viewModel.product = product
                        } label: {
                            HStack {
                                Text(product.displayName).foregroundStyle(ColorTokens.textPrimary)
                                Spacer()
                                if product == viewModel.product {
                                    Image(systemName: "checkmark").foregroundStyle(accent.tint)
                                }
                            }
                        }
                        .accessibilityAddTraits(product == viewModel.product ? .isSelected : [])
                    }
                } header: {
                    Text("¿Qué combustible usas?", bundle: .module)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .textCase(nil)
                        .padding(.bottom, 8)
                }
            }
            .scrollContentBackground(.hidden)
            // Pinned under the list, so it isn't missed below twelve fuels.
            VStack(spacing: 16) {
                TankSizeRow(size: viewModel.tankSize, unit: viewModel.product.unit) { viewModel.setTankSize($0) }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .background(ColorTokens.surface, in: .rect(cornerRadius: 22))
                OnboardingButton(title: Text("Siguiente", bundle: .module), action: viewModel.next)
            }
            .padding(24)
        }
    }
}

struct LocationStep: View {
    let viewModel: OnboardingViewModel

    @Environment(\.accentColors) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(accent.fill)
                .accessibilityHidden(true)
            Text("¿Dónde buscamos?", bundle: .module)
                .font(.screenTitle)
                .foregroundStyle(ColorTokens.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Tu ubicación solo se usa en tu iPhone.", bundle: .module)
                .font(.title3)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
            OnboardingButton(title: Text("Usar mi ubicación", bundle: .module)) {
                Task { await viewModel.useLocation() }
            }
            Button {
                Task { await viewModel.chooseProvinceByHand() }
            } label: {
                Text("Elegir provincia", bundle: .module)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent.tint)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(24)
    }
}
