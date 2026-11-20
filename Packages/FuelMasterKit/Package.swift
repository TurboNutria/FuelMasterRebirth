// swift-tools-version: 6.2
import PackageDescription

// Layers (see Bear note 06): View → ViewModel → Domain ← Data → Network.
// The watch app uses the same Network, Data, Domain and ViewModel layers, with its own views
// (WatchViewLayer). The widget extension draws with WidgetViewLayer only, so it doesn't link the
// app's screens. DesignTokens holds what every view target shares: colours, logos, the look
// environment values, fuel and price-level names, the price chip and the change label.
// Targets carry a "Layer" suffix so they don't clash with Apple's `Network` framework
// or Foundation's `Data` type.
let package = Package(
    name: "FuelMasterKit",
    defaultLocalization: "es",
    platforms: [.iOS(.v26), .macOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "NetworkLayer", targets: ["NetworkLayer"]),
        .library(name: "DomainLayer", targets: ["DomainLayer"]),
        .library(name: "DataLayer", targets: ["DataLayer"]),
        .library(name: "ViewModelLayer", targets: ["ViewModelLayer"]),
        .library(name: "DesignTokens", targets: ["DesignTokens"]),
        .library(name: "ViewLayer", targets: ["ViewLayer"]),
        .library(name: "WatchViewLayer", targets: ["WatchViewLayer"]),
        .library(name: "WidgetViewLayer", targets: ["WidgetViewLayer"]),
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
            name: "DesignTokens",
            dependencies: ["DomainLayer", "ViewModelLayer"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "ViewLayer",
            dependencies: ["ViewModelLayer", "DomainLayer", "DesignTokens", "WidgetViewLayer"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "WidgetViewLayer",
            dependencies: ["ViewModelLayer", "DomainLayer", "DesignTokens"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "WatchViewLayer",
            dependencies: ["ViewModelLayer", "DomainLayer", "DesignTokens"],
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
