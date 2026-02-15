// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BloksParser",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "BloksParser",
            targets: ["BloksParser"]
        ),
    ],
    targets: [
        .target(
            name: "BloksParser"
        ),
        .testTarget(
            name: "BloksParserTests",
            dependencies: ["BloksParser"]
        ),
    ]
)
