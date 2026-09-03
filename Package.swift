// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacAppFoundation",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "MacAppFoundation",
            targets: ["MacAppFoundation"]
        )
    ],
    targets: [
        .target(
            name: "MacAppFoundation"
        ),
        .testTarget(
            name: "MacAppFoundationTests",
            dependencies: ["MacAppFoundation"]
        )
    ],
    swiftLanguageModes: [.v6]
)
