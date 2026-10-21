// swift-tools-version: 6.2
import PackageDescription

// Layers (see Bear note 06): View → ViewModel → Domain ← Data → Network.
// Targets carry a "Layer" suffix so they don't clash with Apple's `Network` framework
// or Foundation's `Data` type.
let package = Package(
    name: "FuelMasterKit",
    defaultLocalization: "es",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "NetworkLayer", targets: ["NetworkLayer"]),
        .library(name: "DomainLayer", targets: ["DomainLayer"]),
        .library(name: "DataLayer", targets: ["DataLayer"]),
        .library(name: "ViewModelLayer", targets: ["ViewModelLayer"]),
        .library(name: "ViewLayer", targets: ["ViewLayer"]),
    ],
    targets: [
        .target(name: "NetworkLayer"),
        .target(name: "DomainLayer"),
        .target(
            name: "DataLayer",
            dependencies: ["DomainLayer", "NetworkLayer"],
            resources: [.process("Resources")]
        ),
        .target(name: "ViewModelLayer", dependencies: ["DomainLayer"]),
        .target(
            name: "ViewLayer",
            dependencies: ["ViewModelLayer", "DomainLayer"],
            resources: [.process("Resources")]
        ),

        .testTarget(name: "NetworkLayerTests", dependencies: ["NetworkLayer"]),
        .testTarget(name: "DomainLayerTests", dependencies: ["DomainLayer"]),
        .testTarget(
            name: "DataLayerTests",
            dependencies: ["DataLayer", "DomainLayer", "NetworkLayer"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "ViewModelLayerTests", dependencies: ["ViewModelLayer", "DomainLayer"]),
    ],
    swiftLanguageModes: [.v6]
)
