import SwiftUI

#if canImport(UIKit)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage
#endif
