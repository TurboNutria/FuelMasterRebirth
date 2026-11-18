import DomainLayer
import SwiftUI
import ViewModelLayer

/// Ajustes (canvas: "Ajustes"): fuel and tank, appearance, language, the province used without
/// location, and the data source. No footnotes: each row says what it is.
public struct SettingsScreen: View {
    let viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            SettingsList {
                // The same rounded title as the other tabs. The system large title sat oddly and
                // pushed things down in the side panel (QA on the Duo, 2026-10-29).
                Text("Ajustes", bundle: .module)
                    .font(.screenTitle)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 8)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                SettingsSection(Text("Tu coche", bundle: .module), spacingAbove: 24) {
                    FuelPicker(product: viewModel.settings.product) { product in
                        Task { await viewModel.select(product) }
                    }
                    TankSizeRow(size: viewModel.settings.tankSize, unit: viewModel.settings.product.unit) { size in
                        Task { await viewModel.setTankSize(size) }
                    }
                }
                SettingsSection(nil) {
                    NavigationLink {
                        AppearanceScreen(viewModel: viewModel)
                    } label: {
                        LabeledContent {
                            Text(verbatim: "\(String(localized: viewModel.settings.accent.name)) · \(String(localized: viewModel.settings.priceScale.name))")
                        } label: {
                            Text("Apariencia", bundle: .module)
                        }
                    }
                    LanguageRow()
                    NavigationLink {
                        ProvincePicker(provinces: viewModel.provinces, selection: viewModel.settings.defaultProvinceID) { id in
                            Task { await viewModel.setDefaultProvince(id) }
                        }
                    } label: {
                        LabeledContent {
                            if let name = viewModel.defaultProvinceName { Text(name) }
                        } label: {
                            Text("Provincia sin ubicación", bundle: .module)
                        }
                    }
                    NavigationLink {
                        LegalScreen(viewModel: viewModel)
                    } label: {
                        Text("Fuente y aviso legal", bundle: .module)
                    }
                }
            }
            #if os(iOS)
            .toolbarVisibility(.hidden, for: .navigationBar)
            #endif
        }
    }
}

/// "Combustible  Diésel ›" as a menu picker.
struct FuelPicker: View {
    let product: Product
    let onSelect: (Product) -> Void

    var body: some View {
        Picker(selection: Binding(get: { product }, set: onSelect)) {
            ForEach(Product.allCases) { Text($0.displayName).tag($0) }
        } label: {
            Text("Combustible", bundle: .module)
        }
    }
}

/// "Depósito  55 l  − +": type it or step it, up to 150.
struct TankSizeRow: View {
    let size: Decimal
    let unit: QuantityUnit
    let onChange: (Decimal) -> Void

    @FocusState private var isFocused: Bool
    /// Room for three digits, growing with the text size.
    @ScaledMetric(relativeTo: .body) private var fieldWidth: CGFloat = 52

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(value: Binding(get: { NSDecimalNumber(decimal: size).intValue },
                                         set: { onChange(Decimal($0)) }),
                          format: .number) {
                    Text("Depósito", bundle: .module)
                }
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: fieldWidth)
                .focused($isFocused)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                Text(unit == .kilogram ? "kg" : "l")
                    .foregroundStyle(ColorTokens.textSecondary)
                Stepper {
                    Text("Depósito", bundle: .module)
                } onIncrement: {
                    onChange(size + 1)
                } onDecrement: {
                    onChange(size - 1)
                }
                .labelsHidden()
            }
        } label: {
            Text("Depósito", bundle: .module)
        }
        .toolbar {
            if isFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "Hecho", bundle: .module)) { isFocused = false }
                }
            }
        }
    }
}

/// "Idioma  Español": the language is per app in the system Settings, so this opens them.
struct LanguageRow: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            #if os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            #endif
        } label: {
            LabeledContent {
                Text(Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "es")?
                    .capitalized(with: Locale.current) ?? "")
            } label: {
                Text("Idioma", bundle: .module).foregroundStyle(ColorTokens.textPrimary)
            }
        }
    }
}

/// The province used when location is off: in Ajustes and at the end of onboarding.
struct ProvincePicker: View {
    let provinces: [Province]
    let selection: ProvinceID?
    let onSelect: (ProvinceID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accentColors) private var accent
    @State private var filter = ""

    var body: some View {
        List(filtered) { province in
            Button {
                onSelect(province.id)
                dismiss()
            } label: {
                HStack {
                    Text(province.name).foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    if province.id == selection {
                        Image(systemName: "checkmark").foregroundStyle(accent.tint)
                    }
                }
            }
            .accessibilityAddTraits(province.id == selection ? .isSelected : [])
            .modifier(SettingsRow(separatorAbove: province.id != filtered.first?.id,
                                  separatorBelow: province.id != filtered.last?.id))
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.background)
        .searchable(text: $filter)
        .navigationTitle(Text("Provincia", bundle: .module))
    }

    private var filtered: [Province] {
        let needle = filter.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return provinces }
        return provinces.filter { $0.name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}

extension AccentChoice {
    var name: LocalizedStringResource {
        switch self {
        case .preset(.orange): LocalizedStringResource("Naranja", bundle: .viewLayer)
        case .preset(.blue): LocalizedStringResource("Azul", bundle: .viewLayer)
        case .preset(.green): LocalizedStringResource("Verde", bundle: .viewLayer)
        case .preset(.purple): LocalizedStringResource("Morado", bundle: .viewLayer)
        case .preset(.pink): LocalizedStringResource("Rosa", bundle: .viewLayer)
        case .preset(.graphite): LocalizedStringResource("Grafito", bundle: .viewLayer)
        case .custom: LocalizedStringResource("Personalizado", bundle: .viewLayer)
        }
    }
}

extension PriceScale {
    var name: LocalizedStringResource {
        switch self {
        case .trafficLight: LocalizedStringResource("Semáforo", bundle: .viewLayer)
        case .blueOrange: LocalizedStringResource("Azul y naranja", bundle: .viewLayer)
        case .monochrome: LocalizedStringResource("Monocromo", bundle: .viewLayer)
        }
    }
}

extension Appearance {
    var name: Text {
        switch self {
        case .system: Text("Sistema", bundle: .module)
        case .light: Text("Claro", bundle: .module)
        case .dark: Text("Oscuro", bundle: .module)
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
