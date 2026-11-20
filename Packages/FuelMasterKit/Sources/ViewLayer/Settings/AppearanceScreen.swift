import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Apariencia (canvas: "Apariencia"): app colour, price colours and light / dark.
struct AppearanceScreen: View {
    let viewModel: SettingsViewModel

    var body: some View {
        SettingsList {
            SettingsSection(Text("Color de la app", bundle: .module), spacingAbove: 8) {
                AccentSwatches(selection: viewModel.settings.accent) { accent in
                    Task { await viewModel.setAccent(accent) }
                }
            }
            SettingsSection(Text("Colores de precio", bundle: .module)) {
                ForEach(PriceScale.allCases, id: \.self) { scale in
                    PriceScaleRow(scale: scale, isSelected: viewModel.settings.priceScale == scale) {
                        Task { await viewModel.setPriceScale(scale) }
                    }
                }
            }
            SettingsSection(Text("Aspecto", bundle: .module)) {
                Picker(selection: Binding(get: { viewModel.settings.appearance },
                                          set: { appearance in Task { await viewModel.setAppearance(appearance) } })) {
                    ForEach(Appearance.allCases, id: \.self) { $0.name.tag($0) }
                } label: {
                    Text("Aspecto", bundle: .module)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .navigationTitle(Text("Apariencia", bundle: .module))
    }
}

/// Six presets and the system colour picker; the ring marks the chosen one.
struct AccentSwatches: View {
    let selection: AccentChoice
    let onSelect: (AccentChoice) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AccentPreset.allCases, id: \.self) { preset in
                swatch(.preset(preset))
                Spacer(minLength: 0)
            }
            ColorPicker(selection: customColor, supportsOpacity: false) {
                Text("Personalizado", bundle: .module)
            }
            .labelsHidden()
            .frame(width: 40, height: 40)
            .overlay {
                if case .custom = selection { ring(for: .custom(currentCustom)) }
            }
        }
        .padding(.vertical, 4)
    }

    private func swatch(_ choice: AccentChoice) -> some View {
        Button {
            onSelect(choice)
        } label: {
            Circle()
                .fill(AccentColors.colors(for: choice).fill)
                .frame(width: 32, height: 32)
                // The ring's size, so the selected ring lines up with the 20 pt margin.
                .frame(width: 40, height: 40)
                .overlay { if choice == selection { ring(for: choice) } }
                // A 44 pt tap area; the negative padding keeps the ring on the margin.
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .padding(-2)
        .buttonStyle(.plain)
        .accessibilityLabel(Text(choice.name))
        .accessibilityAddTraits(choice == selection ? .isSelected : [])
    }

    private func ring(for choice: AccentChoice) -> some View {
        Circle().strokeBorder(AccentColors.colors(for: choice).fill, lineWidth: 2.5).frame(width: 40, height: 40)
    }

    private var currentCustom: CustomColor {
        if case .custom(let rgb) = selection { return rgb }
        return CustomColor(red: 0.043, green: 0.478, blue: 0.463)
    }

    private var customColor: Binding<Color> {
        Binding(get: { Color(currentCustom) }, set: { color in
            let resolved = color.resolve(in: EnvironmentValues())
            onSelect(.custom(CustomColor(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))))
        })
    }
}

/// One price scale: its name over the three sample chips, and a check.
struct PriceScaleRow: View {
    let scale: PriceScale
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.accentColors) private var accent

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(scale.name)
                        .foregroundStyle(ColorTokens.textPrimary)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) { chips }
                        VStack(alignment: .leading, spacing: 4) { chips }
                    }
                    .environment(\.priceScale, scale)
                    .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(accent.tint)
                    .opacity(isSelected ? 1 : 0)
            }
            // The whole row selects, not only the name and the chips.
            .contentShape(.rect)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var chips: some View {
        PriceChip(amount: Decimal(string: "1.859"), level: .cheap)
        PriceChip(amount: Decimal(string: "1.929"), level: .average)
        PriceChip(amount: Decimal(string: "2.019"), level: .expensive)
    }
}
