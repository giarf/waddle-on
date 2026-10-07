// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WaddleOn",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "WaddleOn", targets: ["WaddleOn"])],
    targets: [
        .executableTarget(name: "WaddleOn", exclude: ["Desktop/README.md"], resources: [.copy("Resources")]),
        .testTarget(name: "WaddleOnTests", dependencies: ["WaddleOn"])
    ]
)
