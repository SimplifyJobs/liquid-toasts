// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// The Flutter plugin's iOS package: BRIDGE ONLY. It holds the method/event
// channel plugin and the wire decoding, and gets all rendering from the
// `LiquidToasts` core package declared at the repo root.
//
// `path: "../../.."` walks liquid_toasts/ios/liquid_toasts → repo root, which
// is where the core `Package.swift` lives. That resolves both for the bundled
// example (a path dependency) and for consumers installing via a pubspec `git`
// dependency, since pub clones the whole repo into its cache.
let package = Package(
    name: "liquid_toasts",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .library(name: "liquid-toasts", targets: ["liquid_toasts"])
    ],
    dependencies: [
        .package(name: "liquid-toasts", path: "../../.."),
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "liquid_toasts",
            dependencies: [
                .product(name: "LiquidToasts", package: "liquid-toasts"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // The plugin ships a privacy manifest declaring no data collection
                // and no required-reason API usage (it uses only public APIs).
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
