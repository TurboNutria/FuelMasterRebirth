import DomainLayer
import MapKit
import SwiftUI
import ViewModelLayer

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
