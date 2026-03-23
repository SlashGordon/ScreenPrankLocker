// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScreenPrankLocker",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck", from: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "ScreenPrankLocker",
            path: "Sources/ScreenPrankLocker",
            exclude: [
                "Resources"
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
            ]
        ),
        .testTarget(
            name: "ScreenPrankLockerTests",
            dependencies: [
                "ScreenPrankLocker",
                "SwiftCheck"
            ],
            path: "Tests/ScreenPrankLockerTests"
        )
    ]
)
