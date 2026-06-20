// swift-tools-version: 5.9
// This file documents the project structure. To build, open in Xcode:
// 1. File > New > Project > App (iOS + watchOS)
// 2. Copy source files into the Xcode project targets
// 3. Enable HealthKit capability for both targets
// 4. Add entitlements files to the project

import PackageDescription

let package = Package(
    name: "PancreasGuard",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "PancreasGuardShared", targets: ["PancreasGuardShared"]),
    ],
    targets: [
        .target(
            name: "PancreasGuardShared",
            path: "Shared"
        ),
    ]
)
