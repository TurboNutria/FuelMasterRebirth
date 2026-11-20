import DomainLayer
import MapKit
import SwiftUI
import ViewModelLayer

/// The map and its pins on MapKit's own view. SwiftUI's `Map` hosts a live view per annotation,
/// and a few hundred price chips with shadows dropped the frame rate while panning (QA 2026-11-11).
/// Here every pin is a reused annotation view showing an image, drawn once per look from `MapPinView`.
@MainActor
struct PinMap {
    let pins: [StationPin]
    let highlightedID: StationID?
    let cameraMove: CameraMove?
    /// Where the map starts; read once, when it's made, so the camera's reports don't redraw it.
    let openingCamera: () -> CameraMove?
    let showsUserLocation: Bool
    /// The camera stopped, or the map changed size: the visible area, the map's width and the zoom
    /// (camera height per point of map height, see `CameraMove.zoom`).
    let onViewportChange: (MapViewport, Double, Double) -> Void
    let onTap: (StationPin) -> Void
    let onCameraMoveShown: (CameraMove) -> Void

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
            // The opening camera waited for a size to keep its zoom at; placed before it's drawn.
            if let coordinator, let mapView { coordinator.applyWaitingMove(to: mapView) }
            // Out of the layout pass, so the view model doesn't change while views are being placed.
            DispatchQueue.main.async {
                guard let coordinator, let mapView else { return }
                coordinator.reportViewport(of: mapView)
            }
        }
        coordinator.onViewportChange = onViewportChange
        coordinator.onTap = onTap
        coordinator.onCameraMoveShown = onCameraMoveShown
        // Without animation: there's nothing on screen yet to move from.
        coordinator.apply(openingCamera(), to: mapView, animated: false)
        #if canImport(UIKit)
        mapView.accessibilityCustomRotors = [coordinator.priceRotor(for: mapView)]
        #endif
        return mapView
    }

    private func update(_ mapView: MKMapView, coordinator: Coordinator, environment: EnvironmentValues) {
        coordinator.onViewportChange = onViewportChange
        coordinator.onTap = onTap
        coordinator.onCameraMoveShown = onCameraMoveShown
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
