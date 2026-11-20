import DomainLayer
import MapKit
import SwiftUI
import ViewModelLayer

/// Reports size changes, which move the visible area without moving the camera.
final class ResizeReportingMapView: MKMapView {
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
