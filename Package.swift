// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ConsoleView",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "ConsoleView",
            targets: ["ConsoleView"]
        )
    ],
    targets: [
        .target(
            name: "ConsoleView"),
        .testTarget(
            name: "ConsoleViewTests",
            dependencies: ["ConsoleView"]
        )
    ]
)
