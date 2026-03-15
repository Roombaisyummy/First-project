// swift-tools-version:5.8
// Linux-compatible package for syntax validation

import PackageDescription

let package = Package(
    name: "SatellaJailedModernized",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "SatellaJailedCore",
            targets: ["SatellaJailedCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SatellaJailedCore",
            dependencies: [],
            path: "../Sources/SatellaJailed/Stealth"
        ),
    ]
)
