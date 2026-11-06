// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrewBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BrewBarCore"),
        .executableTarget(
            name: "BrewBar",
            dependencies: ["BrewBarCore"]
        ),
        .testTarget(
            name: "BrewBarCoreTests",
            dependencies: ["BrewBarCore"]
        ),
    ]
)
