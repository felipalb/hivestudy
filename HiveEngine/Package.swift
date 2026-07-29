// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HiveEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HiveEngine", targets: ["HiveEngine"])
    ],
    targets: [
        .target(name: "HiveEngine"),
        .testTarget(name: "HiveEngineTests", dependencies: ["HiveEngine"])
    ]
)
