import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer
#if os(iOS)
import UIKit
#endif

/// What Compartir sends with the Apple Maps link, from the detail and from a row's menu:
/// «Ballenoil · Diésel 1,859 € · Ronda de Segovia, 37, 28005 Madrid».
enum StationShare {
    static func message(_ station: Station, price: Price?, format: DisplayFormat) -> String {
        let address = station.address
        var parts = [station.name]
        if let price {
            parts.append("\(String(localized: price.product.displayName)) \(format.priceWithCurrency(price.amount))")
        }
        parts.append("\(address.street), \(address.postcode) \(address.locality)")
        return parts.joined(separator: " · ")
    }
}

/// The peek of a row held down: the detail's header and its price, from what the row already has.
struct StationPeek: View {
    let summary: StationSummary
    let hours: HoursSummary

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    if let brand = summary.station.brand {
                        BrandLogo(brand: brand, size: 36)
                    }
                    Text(summary.station.name)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                .padding(.bottom, 4)
                Text(addressLine)
                    .foregroundStyle(ColorTokens.textSecondary)
                HStack(spacing: 0) {
                    HoursLabel(hours)
                    if let distance = summary.distance {
                        Text(verbatim: " · \(format.distance(meters: distance))").monospacedDigit()
                    }
                }
                .foregroundStyle(ColorTokens.textSecondary)
            }
            .font(.subheadline)
            PriceHeadline(price: summary.price, level: summary.level)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.background)
    }

    private var addressLine: String {
        let address = summary.station.address
        return "\(address.street) · \(address.postcode) \(address.locality)"
    }
}

extension View {
    /// Holding a row shows its peek with Añadir a / Quitar de favoritos and Compartir; tapping the
    /// peek opens the detail ("pop"). Apply it after the row's other modifiers but before List row
    /// modifiers: on iOS the row moves into a UIKit view that carries the menu.
    func stationContextMenu(_ summary: StationSummary, hours: HoursSummary, isFavorite: Bool,
                            onToggleFavorite: @escaping () -> Void, onOpen: @escaping () -> Void) -> some View {
        modifier(StationContextMenu(summary: summary, hours: hours, isFavorite: isFavorite,
                                    onToggleFavorite: onToggleFavorite, onOpen: onOpen))
    }
}

private struct StationContextMenu: ViewModifier {
    let summary: StationSummary
    let hours: HoursSummary
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onOpen: () -> Void

    @Environment(\.self) private var environment

    func body(content: Content) -> some View {
        #if os(iOS)
        // SwiftUI's own context menu has no way to act on a tap on its preview, so the menu is
        // UIKit's, on a clear view over the row (behind it, the row's button took the long press
        // as a tap); the row itself stays SwiftUI and keeps its VoiceOver element. The peek gets
        // this environment (format, accent, price scale).
        content.overlay {
            PeekAndPop(preview: AnyView(StationPeek(summary: summary, hours: hours).environment(\.self, environment)),
                       actions: actions)
        }
        #else
        content.contextMenu {
            Button(action: onToggleFavorite) { favoriteLabel }
            if let url = summary.station.shareURL {
                ShareLink(item: url, message: Text(shareMessage)) {
                    Label { Text("Compartir", bundle: .module) } icon: { Image(systemName: "square.and.arrow.up") }
                }
            }
        } preview: {
            StationPeek(summary: summary, hours: hours)
        }
        #endif
    }

    private var shareMessage: String {
        StationShare.message(summary.station, price: summary.price, format: environment.displayFormat)
    }

    private var favoriteLabel: some View {
        Label {
            isFavorite ? Text("Quitar de favoritos", bundle: .module) : Text("Añadir a favoritos", bundle: .module)
        } icon: {
            Image(systemName: isFavorite ? "star.slash" : "star")
        }
    }

    #if os(iOS)
    private var actions: PeekAndPopActions {
        PeekAndPopActions(
            favoriteTitle: isFavorite ? String(localized: "Quitar de favoritos", bundle: .module)
                : String(localized: "Añadir a favoritos", bundle: .module),
            favoriteImage: isFavorite ? "star.slash" : "star",
            shareItems: [shareMessage as Any] + (summary.station.shareURL.map { [$0 as Any] } ?? []),
            onToggleFavorite: onToggleFavorite,
            onOpen: onOpen
        )
    }
    #endif
}

#if os(iOS)
struct PeekAndPopActions {
    let favoriteTitle: String
    let favoriteImage: String
    let shareItems: [Any]
    let onToggleFavorite: () -> Void
    let onOpen: () -> Void
}

/// A clear view over the row with a context menu interaction: the peek controller, the menu, and
/// the commit (tapping the peek) that opens the detail. A tap opens it too, since the row's button
/// below no longer gets touches. The lift is a snapshot of the row as drawn on screen.
private struct PeekAndPop: UIViewRepresentable {
    let preview: AnyView
    let actions: PeekAndPopActions

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.addInteraction(UIContextMenuInteraction(delegate: context.coordinator))
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator,
                                                         action: #selector(Coordinator.tapped)))
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    @MainActor final class Coordinator: NSObject, UIContextMenuInteractionDelegate {
        var parent: PeekAndPop
        /// The lift, kept so the menu settles back onto the same picture.
        private var lifted: UITargetedPreview?

        init(parent: PeekAndPop) {
            self.parent = parent
        }

        @objc func tapped() { parent.actions.onOpen() }

        func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
            let windowWidth = interaction.view?.window?.bounds.width ?? 390
            return UIContextMenuConfiguration(identifier: nil) { [parent] in
                let controller = UIHostingController(rootView: parent.preview)
                let width = min(windowWidth - 32, 420)
                let height = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
                controller.preferredContentSize = CGSize(width: width, height: height)
                return controller
            } actionProvider: { [weak self] _ in
                self?.menu(from: interaction.view)
            }
        }

        func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                                    animator: any UIContextMenuInteractionCommitAnimating) {
            let onOpen = parent.actions.onOpen
            animator.addCompletion { onOpen() }
        }

        func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    configuration: UIContextMenuConfiguration,
                                    highlightPreviewForItemWithIdentifier identifier: any NSCopying) -> UITargetedPreview? {
            lifted = interaction.view.flatMap(snapshotPreview)
            return lifted
        }

        func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    configuration: UIContextMenuConfiguration,
                                    dismissalPreviewForItemWithIdentifier identifier: any NSCopying) -> UITargetedPreview? {
            defer { lifted = nil }
            return lifted
        }

        /// The row as drawn, with a little room each side, on the page colour with rounded corners.
        private func snapshotPreview(of view: UIView) -> UITargetedPreview? {
            guard let window = view.window else { return nil }
            let frame = view.convert(view.bounds, to: window).insetBy(dx: -12, dy: 0)
            guard let snapshot = window.resizableSnapshotView(from: frame, afterScreenUpdates: false,
                                                              withCapInsets: .zero) else { return nil }
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = UIColor(ColorTokens.background)
            parameters.visiblePath = UIBezierPath(roundedRect: CGRect(origin: .zero, size: frame.size), cornerRadius: 16)
            let target = UIPreviewTarget(container: view, center: CGPoint(x: view.bounds.midX, y: view.bounds.midY))
            return UITargetedPreview(view: snapshot, parameters: parameters, target: target)
        }

        private func menu(from view: UIView?) -> UIMenu {
            let actions = parent.actions
            let favorite = UIAction(title: actions.favoriteTitle, image: UIImage(systemName: actions.favoriteImage)) { _ in
                actions.onToggleFavorite()
            }
            let share = UIAction(title: String(localized: "Compartir", bundle: .module),
                                 image: UIImage(systemName: "square.and.arrow.up")) { [weak view] _ in
                guard let view else { return }
                Self.share(actions.shareItems, from: view)
            }
            return UIMenu(children: [favorite, share])
        }

        private static func share(_ items: [Any], from view: UIView) {
            guard var presenter = view.window?.rootViewController else { return }
            while let presented = presenter.presentedViewController { presenter = presented }
            let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
            controller.popoverPresentationController?.sourceView = view
            controller.popoverPresentationController?.sourceRect = view.bounds
            presenter.present(controller, animated: true)
        }
    }
}
#endif
