// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VPNCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "VPNCore", targets: ["VPNCore"])],
    targets: [
        .target(name: "VPNCore"),
        .testTarget(name: "VPNCoreTests", dependencies: ["VPNCore"])
    ]
)
