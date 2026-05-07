// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "core_bluetooth",
    platforms: [
        .iOS("12.0"),
        .macOS("10.14"),
    ],
    products: [
        .library(name: "core-bluetooth", targets: ["core_bluetooth"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "core_bluetooth",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
            ]
        )
    ]
)
