// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "remain",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RemainCore", targets: ["RemainCore"]),
        .executable(name: "remain", targets: ["remain"]),
        .executable(name: "RemainApp", targets: ["RemainApp"]),
    ],
    targets: [
        .target(name: "RemainCore"),
        .executableTarget(name: "remain", dependencies: ["RemainCore"]),
        .executableTarget(name: "RemainApp", dependencies: ["RemainCore"]),
        .testTarget(name: "RemainCoreTests", dependencies: ["RemainCore"]),
    ]
)
