import DomainLayer
import MapKit
import SwiftUI
import ViewModelLayer

#if canImport(UIKit)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage
#endif

/// The map and its pins on MapKit's own view. SwiftUI's `Map` hosts a live view per annotation,
/// and a few hundred price chips with shadows dropped the frame rate while panning (QA 2026-11-11).
/// Here every pin is a reused annotation view showing an image, drawn once per look from `MapPinView`.
@MainActor
struct PinMap {
    let pins: [StationPin]
    let highlightedID: StationID?
    let cameraMove: CameraMove?
    let showsUserLocation: Bool
    /// The camera stopped, or the map changed size: the visible area, the map's width and the camera height.
    let onViewportChange: (MapViewport, Double, Double) -> Void
    let onTap: (StationPin) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func makeMap(coordinator: Coordinator) -> MKMapView {
        let mapView = ResizeReportingMapView()
        // Muted, so the base map stays grey and the prices are the only colour on it.
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: Coordinator.reuseIdentifier)
        mapView.delegate = coordinator
        mapView.onResize = { [weak coordinator, weak mapView] in
            // Out of the layout pass, so the view model doesn't change while views are being placed.
            DispatchQueue.main.async {
                guard let coordinator, let mapView else { return }
                coordinator.reportViewport(of: mapView)
            }
        }
        coordinator.onViewportChange = onViewportChange
        coordinator.onTap = onTap
        // Without animation: there's nothing on screen yet to move from.
        coordinator.apply(cameraMove, to: mapView, animated: false)
        #if canImport(UIKit)
        mapView.accessibilityCustomRotors = [coordinator.priceRotor(for: mapView)]
        #endif
        return mapView
    }

    private func update(_ mapView: MKMapView, coordinator: Coordinator, environment: EnvironmentValues) {
        coordinator.onViewportChange = onViewportChange
        coordinator.onTap = onTap
        if mapView.showsUserLocation != showsUserLocation { mapView.showsUserLocation = showsUserLocation }
        coordinator.show(pins, highlightedID: highlightedID, on: mapView, environment: environment)
        coordinator.apply(cameraMove, to: mapView, animated: true)
    }
}

#if canImport(UIKit)
extension PinMap: UIViewRepresentable {
    func makeUIView(context: Context) -> MKMapView { makeMap(coordinator: context.coordinator) }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        update(mapView, coordinator: context.coordinator, environment: context.environment)
    }
}
#else
extension PinMap: NSViewRepresentable {
    func makeNSView(context: Context) -> MKMapView { makeMap(coordinator: context.coordinator) }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        update(mapView, coordinator: context.coordinator, environment: context.environment)
    }
}
#endif

extension PinMap {
    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        static let reuseIdentifier = "pin"
        /// Room around a pin's image for its shadow.
        static let imagePadding: CGFloat = 12

        var onViewportChange: (MapViewport, Double, Double) -> Void = { _, _, _ in }
        var onTap: (StationPin) -> Void = { _ in }

        private var pins: [StationPin] = []
        private var annotations: [String: PinAnnotation] = [:]
        private var highlightedID: StationID?
        private var lastMoveID: Int?
        private var look: PinLook?
        private var environment = EnvironmentValues()
        private var images: [PinImageKey: PlatformImage] = [:]
        private let renderer = ImageRenderer(content: AnyView(EmptyView()))

        // MARK: Pins

        /// Adds, removes and redraws only the pins that changed.
        func show(_ pins: [StationPin], highlightedID: StationID?, on mapView: MKMapView, environment: EnvironmentValues) {
            let look = PinLook(environment)
            let isRestyled = look != self.look
            if isRestyled {
                self.look = look
                self.environment = environment
                images.removeAll()
            }
            let previousHighlight = self.highlightedID
            self.highlightedID = highlightedID

            if pins != self.pins {
                self.pins = pins
                var stale = annotations
                var added: [PinAnnotation] = []
                var seen: Set<String> = []
                for pin in pins where seen.insert(pin.id).inserted {
                    if let annotation = stale.removeValue(forKey: pin.id) {
                        guard annotation.pin != pin else { continue }
                        annotation.pin = pin
                        annotation.coordinate = pin.coordinate.location
                        if let view = mapView.view(for: annotation) { configure(view, for: annotation) }
                    } else {
                        let annotation = PinAnnotation(pin)
                        annotations[pin.id] = annotation
                        added.append(annotation)
                    }
                }
                for id in stale.keys { annotations[id] = nil }
                mapView.removeAnnotations(Array(stale.values))
                mapView.addAnnotations(added)
            }

            if isRestyled {
                for annotation in annotations.values {
                    if let view = mapView.view(for: annotation) { configure(view, for: annotation) }
                }
            } else if previousHighlight != highlightedID {
                for id in [previousHighlight, highlightedID].compactMap(\.self) {
                    guard let annotation = annotations[StationPin.stationPinID(id)],
                          let view = mapView.view(for: annotation) else { continue }
                    configure(view, for: annotation)
                    if id == highlightedID { pop(view) }
                }
            }
        }

        private func isHighlighted(_ pin: StationPin) -> Bool {
            guard case .station(let summary) = pin else { return false }
            return summary.id == highlightedID
        }

        private func configure(_ view: MKAnnotationView, for annotation: PinAnnotation) {
            let isHighlighted = isHighlighted(annotation.pin)
            let image = image(for: annotation.pin, isHighlighted: isHighlighted)
            view.image = image
            // The pin's bottom edge sits on the station, as the image carries padding for the shadow.
            view.centerOffset = CGPoint(x: 0, y: -(image.size.height / 2 - Self.imagePadding))
            view.canShowCallout = false
            view.displayPriority = .required
            view.zPriority = isHighlighted ? .max : .defaultUnselected
            let label = annotation.pin.accessibilityText(format: environment.displayFormat)
            #if canImport(UIKit)
            view.isAccessibilityElement = true
            view.accessibilityLabel = label
            view.accessibilityTraits = .button
            #else
            view.setAccessibilityElement(true)
            view.setAccessibilityLabel(label)
            view.setAccessibilityRole(.button)
            #endif
        }

        /// The large pin springs up when its station is selected.
        private func pop(_ view: MKAnnotationView) {
            #if canImport(UIKit)
            guard !environment.accessibilityReduceMotion else { return }
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                view.transform = .identity
            }
            #endif
        }

        private func image(for pin: StationPin, isHighlighted: Bool) -> PlatformImage {
            let key = PinImageKey(pin, isHighlighted: isHighlighted)
            if let image = images[key] { return image }
            renderer.content = AnyView(
                MapPinView(pin: pin, isHighlighted: isHighlighted)
                    .padding(Self.imagePadding)
                    .environment(\.self, environment)
            )
            renderer.scale = environment.displayScale
            #if canImport(UIKit)
            let image = renderer.uiImage ?? UIImage()
            #else
            let image = renderer.nsImage ?? NSImage()
            #endif
            images[key] = image
            return image
        }

        // MARK: VoiceOver

        #if canImport(UIKit)
        /// «Gasolineras por precio»: the pins on screen from the cheapest to the dearest (canvas:
        /// VoiceOver board). Groups count at their cheapest price; first-load pins are skipped.
        func priceRotor(for mapView: MKMapView) -> UIAccessibilityCustomRotor {
            UIAccessibilityCustomRotor(name: String(localized: "Gasolineras por precio", bundle: .module)) {
                [weak self, weak mapView] predicate in
                MainActor.assumeIsolated {
                    guard let self, let mapView else { return nil }
                    let views = self.visibleByPrice(on: mapView).compactMap { mapView.view(for: $0) }
                    let current = (predicate.currentItem.targetElement as? MKAnnotationView).flatMap { views.firstIndex(of: $0) }
                    let next: Int
                    switch predicate.searchDirection {
                    case .next: next = current.map { $0 + 1 } ?? 0
                    case .previous: next = current.map { $0 - 1 } ?? views.count - 1
                    @unknown default: return nil
                    }
                    guard views.indices.contains(next) else { return nil }
                    return UIAccessibilityCustomRotorItemResult(targetElement: views[next], targetRange: nil)
                }
            }
        }

        private func visibleByPrice(on mapView: MKMapView) -> [PinAnnotation] {
            let visible = mapView.annotations(in: mapView.visibleMapRect).compactMap { $0 as? PinAnnotation }
            return visible.compactMap { annotation in annotation.pin.price.map { (annotation, $0) } }
                .sorted { $0.1 < $1.1 }
                .map(\.0)
        }
        #endif

        // MARK: Camera

        func apply(_ move: CameraMove?, to mapView: MKMapView, animated: Bool) {
            guard let move, move.id != lastMoveID else { return }
            lastMoveID = move.id
            if let distance = move.distance {
                let camera = MKMapCamera(lookingAtCenter: move.viewport.center.location, fromDistance: distance,
                                         pitch: 0, heading: 0)
                mapView.setCamera(camera, animated: animated)
            } else {
                mapView.setRegion(move.viewport.region, animated: animated)
            }
        }

        func reportViewport(of mapView: MKMapView) {
            guard mapView.bounds.width > 0 else { return }
            onViewportChange(MapViewport(mapView.region), mapView.bounds.width, mapView.camera.centerCoordinateDistance)
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            // Nil keeps MapKit's own view for the user's location.
            guard let annotation = annotation as? PinAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: Self.reuseIdentifier, for: annotation)
            configure(view, for: annotation)
            return view
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            reportViewport(of: mapView)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Selection is only used as a tap: the open station is highlighted through the router.
            mapView.deselectAnnotation(view.annotation, animated: false)
            guard let annotation = view.annotation as? PinAnnotation else { return }
            onTap(annotation.pin)
        }
    }
}

/// A pin as MapKit holds it. The same object stays on the map while its station does.
final class PinAnnotation: NSObject, MKAnnotation {
    var pin: StationPin
    /// Observed by MapKit, which moves the view when it changes.
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(_ pin: StationPin) {
        self.pin = pin
        coordinate = pin.coordinate.location
    }
}

/// Reports size changes, which move the visible area without moving the camera.
private final class ResizeReportingMapView: MKMapView {
    var onResize: (() -> Void)?
    private var lastSize = CGSize.zero

    #if canImport(UIKit)
    override func layoutSubviews() {
        super.layoutSubviews()
        reportIfResized()
    }
    #else
    override func layout() {
        super.layout()
        reportIfResized()
    }
    #endif

    private func reportIfResized() {
        guard bounds.size != lastSize else { return }
        lastSize = bounds.size
        onResize?()
    }
}

/// What a pin's image shows: pins with the same key share one image.
private enum PinImageKey: Hashable {
    case price(Decimal, PriceLevel, Brand?, isHighlighted: Bool)
    case cluster(Int)
    case placeholder

    init(_ pin: StationPin, isHighlighted: Bool) {
        switch pin {
        case .station(let summary):
            self = .price(summary.price.amount, summary.level, summary.station.brand, isHighlighted: isHighlighted)
        case .cluster(_, let count, _): self = .cluster(count)
        case .placeholder: self = .placeholder
        }
    }
}

/// Everything outside a pin that changes how it's drawn. A change redraws every image.
private struct PinLook: Equatable {
    let priceScale: PriceScale
    let locale: Locale
    let colorScheme: ColorScheme
    let contrast: ColorSchemeContrast
    let typeSize: DynamicTypeSize
    let differentiateWithoutColor: Bool
    let displayScale: CGFloat

    init(_ environment: EnvironmentValues) {
        priceScale = environment.priceScale
        locale = environment.displayFormat.locale
        colorScheme = environment.colorScheme
        contrast = environment.colorSchemeContrast
        typeSize = environment.dynamicTypeSize
        differentiateWithoutColor = environment.accessibilityDifferentiateWithoutColor
        displayScale = environment.displayScale
    }
}
