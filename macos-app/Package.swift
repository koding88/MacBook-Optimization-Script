// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacBookOptimizationApp",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacBookOptimizationApp",
            targets: ["MacBookOptimizationApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacBookOptimizationApp",
            path: "Sources/MacBookOptimizationApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MacBookOptimizationAppTests",
            dependencies: ["MacBookOptimizationApp"],
            path: "Tests/MacBookOptimizationAppTests"
        )
    ]
)
