// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// The Flutter plugin's iOS package. It carries two modules: the `liquid_toasts`
// bridge (method/event channel plugin and wire decoding) and the `LiquidToasts`
// core it renders through.
//
// `Sources/LiquidToasts` is a SYMLINK to `liquid-toasts-swift/Sources/
// LiquidToasts` — the core lives there and is compiled from there by the
// repo-root manifest too, so it exists exactly once with no vendored copy.
//
// Every path this manifest NAMES stays inside the package directory, and that
// is load-bearing: Flutter resolves a plugin through a symlink in the consuming
// app (`ios/Flutter/ephemeral/Packages/.packages/<plugin>`), and SwiftPM
// resolves a manifest's relative paths against that symlink rather than the
// checkout it points into. A path reaching above this directory would land in
// the app's ephemeral folder and fail resolution. The symlink above is
// different in kind: the filesystem follows it from its own real location in
// the checkout, so it lands on the core wherever the checkout is.
let package = Package(
    name: "liquid_toasts",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .library(name: "liquid-toasts", targets: ["liquid_toasts"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        // The SwiftUI core: the renderer, the stack, the scheduler and the
        // `LiquidToast` facade. No `import Flutter` anywhere.
        .target(
            name: "LiquidToasts",
            resources: [
                // Ships a privacy manifest declaring no data collection and no
                // required-reason API usage (it uses only public APIs).
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "liquid_toasts",
            dependencies: [
                "LiquidToasts",
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
