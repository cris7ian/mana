// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ManaCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v13), .iOS(.v18)],
    products: [.library(name: "ManaCore", targets: ["ManaCore"])],
    targets: [
        .target(name: "ManaCore", resources: [.process("Resources")]),
        .testTarget(name: "ManaCoreTests", dependencies: ["ManaCore"], resources: [.process("Fixtures")])
    ]
)
