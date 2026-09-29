// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacAppFoundation",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .library(
            name: "MacAppFoundation",
            targets: ["MacAppFoundation"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-log.git",
            from: "1.11.0"
        )
    ],
    targets: [
        .target(
            name: "MacAppFoundation",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "MacAppFoundationTests",
            dependencies: ["MacAppFoundation"]
        )
    ],
    swiftLanguageModes: [.v6]
)
