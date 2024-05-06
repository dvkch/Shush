// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shush",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(name: "Shush", targets: ["Shush"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Shush", dependencies: []),
        .testTarget(name: "ShushTests", dependencies: ["Shush"]),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
