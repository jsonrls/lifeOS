// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LifeKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "LifeCore", targets: ["LifeCore"]),
        .library(name: "CityEngine", targets: ["CityEngine"]),
    ],
    targets: [
        .target(name: "LifeCore"),
        .target(name: "CityEngine", dependencies: ["LifeCore"]),
        .testTarget(name: "LifeCoreTests", dependencies: ["LifeCore"]),
        .testTarget(name: "CityEngineTests", dependencies: ["CityEngine", "LifeCore"]),
    ]
)
