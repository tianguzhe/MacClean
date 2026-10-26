// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacCleanCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "MacCleanCore", targets: ["MacCleanCore"])],
    targets: [
        .target(name: "MacCleanCore"),
        .testTarget(name: "MacCleanCoreTests", dependencies: ["MacCleanCore"])
    ]
)
